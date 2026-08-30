#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float phase;
    vec2 logicalSize;
    float devicePixelRatio;
    vec4 accentColor;
    vec4 borderColor;
};

void main()
{
    vec2 size = max(logicalSize, vec2(1.0));
    float dpr = max(devicePixelRatio, 1.0);
    float centeredY = (qt_TexCoord0.y - 0.5) * size.y * dpr;
    float edgeFade = smoothstep(0.0, 0.13, qt_TexCoord0.x)
        * (1.0 - smoothstep(0.87, 1.0, qt_TexCoord0.x));

    float carrier = 1.0 - smoothstep(0.45 * dpr, 1.35 * dpr, abs(centeredY));
    float waveOffset = sin(qt_TexCoord0.x * 18.0 + phase * 6.2831853) * 0.72 * dpr;
    float filament = 1.0 - smoothstep(0.30 * dpr, 0.95 * dpr, abs(centeredY - waveOffset));
    float pulse = pow(0.5 + 0.5 * sin(qt_TexCoord0.x * 10.0 - phase * 6.2831853), 6.0);

    float coverage = edgeFade * max(carrier * 0.42, filament * (0.18 + pulse * 0.30));
    float accentMix = clamp(filament * (0.24 + pulse * 0.42), 0.0, 0.72);
    vec4 ink = mix(borderColor, accentColor, accentMix);
    float alpha = coverage * ink.a * qt_Opacity;
    vec3 straightColor = ink.a > 0.0 ? ink.rgb / ink.a : vec3(0.0);
    fragColor = vec4(straightColor * alpha, alpha);
}
