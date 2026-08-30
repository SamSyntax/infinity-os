#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float phase;
    vec2 logicalSize;
    float devicePixelRatio;
    vec4 inkColor;
    vec4 shadowColor;
};

float hash21(vec2 point)
{
    vec3 folded = fract(vec3(point.xyx) * vec3(0.1031, 0.1030, 0.0973));
    folded += dot(folded, folded.yzx + 33.33);
    return fract((folded.x + folded.y) * folded.z);
}

void main()
{
    vec2 size = max(logicalSize, vec2(1.0));
    float dpr = max(devicePixelRatio, 1.0);
    vec2 point = qt_TexCoord0 - 0.5;
    point.x *= size.x / size.y;

    float radius = length(point);
    float angle = atan(point.y, point.x);
    vec2 discPoint = vec2(point.x, point.y * 1.78);
    float discRadius = length(discPoint);
    float orbitalTexture = sin(angle * 11.0 - phase * 6.2831853 + radius * 74.0);

    float accretion = exp(-pow((discRadius - 0.245) / 0.027, 2.0));
    float innerRing = exp(-pow((discRadius - 0.198) / 0.010, 2.0));
    float lensedArc = exp(-pow((radius - 0.228) / 0.018, 2.0))
        * smoothstep(-0.045, 0.15, -point.y);
    float directional = 0.58 + 0.42 * smoothstep(-0.72, 0.78, cos(angle - 0.38));

    float paperValue = accretion * directional * (0.68 + orbitalTexture * 0.16)
        + innerRing * 0.34
        + lensedArc * 0.44;
    float horizon = 1.0 - smoothstep(0.145, 0.164, radius);
    float lensShade = (1.0 - smoothstep(0.164, 0.205, radius)) * (1.0 - horizon) * 0.17;

    vec2 devicePixel = floor(qt_TexCoord0 * size * dpr);
    float grain = hash21(devicePixel + floor(phase * 12.0));
    float ordered = mod(devicePixel.x + devicePixel.y * 2.0, 4.0) * 0.25;
    float threshold = mix(ordered, grain, 0.56);
    float dithered = floor(clamp(paperValue, 0.0, 1.0) * 5.0 + threshold) / 5.0;

    float edgeFade = 1.0 - smoothstep(0.34, 0.48, radius);
    float artworkAlpha = edgeFade * clamp(max(dithered, horizon * 0.92) + lensShade, 0.0, 1.0);
    vec4 archiveInk = mix(shadowColor, inkColor, dithered);
    float alpha = artworkAlpha * archiveInk.a * qt_Opacity;
    vec3 straightColor = archiveInk.a > 0.0 ? archiveInk.rgb / archiveInk.a : vec3(0.0);
    fragColor = vec4(straightColor * alpha, alpha);
}
