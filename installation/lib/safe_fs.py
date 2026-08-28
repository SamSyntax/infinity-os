import errno
import os
import pwd
import re
import secrets
import stat
from pathlib import Path, PurePosixPath


USERNAME = re.compile(r"^[a-z_][a-z0-9_-]{0,31}$")


def validate_user(value: str) -> str:
    if not USERNAME.fullmatch(value):
        raise ValueError(
            f"invalid target user {value!r}; expected a portable Unix account name"
        )
    return value


def validate_relative(value: str) -> Path:
    pure = PurePosixPath(value)
    if pure.is_absolute() or not pure.parts or any(part in {"", ".", ".."} for part in pure.parts):
        raise ValueError(f"unsafe relative path: {value!r}")
    return Path(*pure.parts)


def resolve_root(value: str) -> Path:
    root = Path(value).resolve(strict=True)
    if not root.is_dir():
        raise ValueError(f"target root is not a directory: {root}")
    return root


def target_identity(root: Path, user: str):
    if os.geteuid() != 0:
        return None
    if root == Path("/"):
        record = pwd.getpwnam(user)
        return record.pw_uid, record.pw_gid
    passwd = root / "etc/passwd"
    try:
        lines = passwd.read_text(encoding="utf-8").splitlines()
    except OSError as error:
        raise ValueError(f"cannot resolve target user from {passwd}: {error}") from error
    for line in lines:
        fields = line.split(":")
        if len(fields) >= 4 and fields[0] == user:
            return int(fields[2]), int(fields[3])
    raise ValueError(f"target user {user!r} is absent from {passwd}")


def _open_parent(root: Path, destination: Path, owner=None):
    relative = destination.relative_to(root)
    parts = relative.parts[:-1]
    fd = os.open(root, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        for part in parts:
            try:
                os.mkdir(part, mode=0o755, dir_fd=fd)
                if owner is not None:
                    os.chown(part, owner[0], owner[1], dir_fd=fd, follow_symlinks=False)
            except FileExistsError:
                metadata = os.stat(part, dir_fd=fd, follow_symlinks=False)
                if stat.S_ISLNK(metadata.st_mode) or not stat.S_ISDIR(metadata.st_mode):
                    raise ValueError(f"refusing unsafe destination parent: {destination}")
            next_fd = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
            os.close(fd)
            fd = next_fd
        return fd, relative.name
    except BaseException:
        os.close(fd)
        raise


def read_regular(root: Path, destination: Path):
    parent_fd, name = _open_parent(root, destination)
    try:
        try:
            fd = os.open(name, os.O_RDONLY | os.O_NOFOLLOW, dir_fd=parent_fd)
        except FileNotFoundError:
            return None
        try:
            metadata = os.fstat(fd)
            if not stat.S_ISREG(metadata.st_mode):
                raise ValueError(f"refusing non-regular destination: {destination}")
            with os.fdopen(fd, "rb", closefd=False) as handle:
                return handle.read(), stat.S_IMODE(metadata.st_mode)
        finally:
            os.close(fd)
    finally:
        os.close(parent_fd)


def read_existing_regular(root: Path, source: Path) -> bytes:
    relative = source.relative_to(root)
    fd = os.open(root, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        for part in relative.parts[:-1]:
            next_fd = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
            os.close(fd)
            fd = next_fd
        file_fd = os.open(relative.name, os.O_RDONLY | os.O_NOFOLLOW, dir_fd=fd)
        try:
            metadata = os.fstat(file_fd)
            if not stat.S_ISREG(metadata.st_mode):
                raise ValueError(f"refusing non-regular source: {source}")
            chunks = []
            while True:
                chunk = os.read(file_fd, 1024 * 1024)
                if not chunk:
                    return b"".join(chunks)
                chunks.append(chunk)
        finally:
            os.close(file_fd)
    finally:
        os.close(fd)


def atomic_write(root: Path, destination: Path, data: bytes, mode: int, owner=None):
    parent_fd, name = _open_parent(root, destination, owner)
    temporary = f".infinity-{secrets.token_hex(12)}"
    try:
        try:
            current = os.stat(name, dir_fd=parent_fd, follow_symlinks=False)
            if stat.S_ISLNK(current.st_mode) or not stat.S_ISREG(current.st_mode):
                raise ValueError(f"refusing unsafe destination: {destination}")
        except FileNotFoundError:
            pass
        fd = os.open(
            temporary,
            os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
            mode,
            dir_fd=parent_fd,
        )
        try:
            with os.fdopen(fd, "wb", closefd=False) as handle:
                handle.write(data)
                handle.flush()
                os.fsync(fd)
            os.fchmod(fd, mode)
            if owner is not None:
                os.fchown(fd, owner[0], owner[1])
        finally:
            os.close(fd)
        os.replace(temporary, name, src_dir_fd=parent_fd, dst_dir_fd=parent_fd)
    finally:
        try:
            os.unlink(temporary, dir_fd=parent_fd)
        except OSError as error:
            if error.errno != errno.ENOENT:
                raise
        os.close(parent_fd)


def init_regular(root: Path, destination: Path, mode: int = 0o644, owner=None):
    parent_fd, name = _open_parent(root, destination, owner)
    try:
        try:
            current = os.stat(name, dir_fd=parent_fd, follow_symlinks=False)
            if stat.S_ISLNK(current.st_mode) or not stat.S_ISREG(current.st_mode):
                raise ValueError(f"refusing unsafe log destination: {destination}")
        except FileNotFoundError:
            pass
        fd = os.open(
            name,
            os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW,
            mode,
            dir_fd=parent_fd,
        )
        try:
            os.fchmod(fd, mode)
            if owner is not None:
                os.fchown(fd, owner[0], owner[1])
            os.fsync(fd)
        finally:
            os.close(fd)
    finally:
        os.close(parent_fd)


def append_regular(root: Path, destination: Path, data: bytes, mode: int = 0o644, owner=None):
    parent_fd, name = _open_parent(root, destination, owner)
    try:
        try:
            current = os.stat(name, dir_fd=parent_fd, follow_symlinks=False)
            if stat.S_ISLNK(current.st_mode) or not stat.S_ISREG(current.st_mode):
                raise ValueError(f"refusing unsafe log destination: {destination}")
        except FileNotFoundError:
            pass
        fd = os.open(
            name,
            os.O_WRONLY | os.O_CREAT | os.O_APPEND | os.O_NOFOLLOW,
            mode,
            dir_fd=parent_fd,
        )
        try:
            pending = memoryview(data)
            while pending:
                written = os.write(fd, pending)
                if written == 0:
                    raise OSError(errno.EIO, f"short write appending to {destination}")
                pending = pending[written:]
            os.fchmod(fd, mode)
            if owner is not None:
                os.fchown(fd, owner[0], owner[1])
            os.fsync(fd)
        finally:
            os.close(fd)
    finally:
        os.close(parent_fd)


def remove_regular(root: Path, destination: Path):
    parent_fd, name = _open_parent(root, destination)
    try:
        try:
            metadata = os.stat(name, dir_fd=parent_fd, follow_symlinks=False)
        except FileNotFoundError:
            return
        if stat.S_ISLNK(metadata.st_mode) or not stat.S_ISREG(metadata.st_mode):
            raise ValueError(f"refusing to remove unsafe destination: {destination}")
        os.unlink(name, dir_fd=parent_fd)
    finally:
        os.close(parent_fd)
