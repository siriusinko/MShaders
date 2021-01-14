////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////                                                                        ////
////                    MMMMMMMM               MMMMMMMM                     ////
////                    M:::::::M             M:::::::M                     ////
////                    M::::::::M           M::::::::M                     ////
////                    M:::::::::M         M:::::::::M                     ////
////                    M::::::::::M       M::::::::::M                     ////
////                    M:::::::::::M     M:::::::::::M                     ////
////                    M:::::::M::::M   M::::M:::::::M                     ////
////                    M::::::M M::::M M::::M M::::::M                     ////
////                    M::::::M  M::::M::::M  M::::::M                     ////
////                    M::::::M   M:::::::M   M::::::M                     ////
////                    M::::::M    M:::::M    M::::::M                     ////
////                    M::::::M     MMMMM     M::::::M                     ////
////                    M::::::M               M::::::M                     ////
////                    M::::::M               M::::::M                     ////
////                    M::::::M               M::::::M                     ////
////                    MMMMMMMM               MMMMMMMM                     ////
////                                                                        ////
////                          MShaders <> by TreyM                          ////
////                          ATMOSPHERIC  DENSITY                          ////
////                                                                        ////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
//// DO NOT REDISTRIBUTE WITHOUT PERMISSION                                 ////
////////////////////////////////////////////////////////////////////////////////


// FILE SETUP //////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

// Configure MShadersCommon.fxh
#define _TIMER       // Enable ReShade timer
#define _DITHER      // Enable Dither function
#define _DEPTH_CHECK // Enable checking for depth buffer

#include "ReShade.fxh"
#include "Include/MShadersMacros.fxh"
#include "Include/MShadersCommon.fxh"


// UI VARIABLES ////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

#define CATEGORY "Fog Physical Properties" /////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
UI_INT_S (DISTANCE, "Density", "", 1, 100, 75, 0)
UI_INT_S (HIGHLIGHT_DIST, "Highlight Distance", "", 0, 100, 100, 0)
UI_COLOR (FOG_TINT, "Fog Color", "", 0.4, 0.45, 0.5, 0)
#undef  CATEGORY ///////////////////////////////////////////////////////////////


// FUNCTIONS ///////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
#include "Include/Functions/AVGen.fxh"

float3 BlurH (float3 color, sampler SamplerColor, float2 coord)
{
    float offset[18] =
    {
        0.0,            1.4953705027, 3.4891992113,
        5.4830312105,   7.4768683759, 9.4707125766,
        11.4645656736, 13.4584295168, 15.4523059431,
        17.4461967743, 19.4661974725, 21.4627427973,
        23.4592916956, 25.455844494,  27.4524015179,
        29.4489630909, 31.445529535,  33.4421011704
    };

    float kernel[18] =
    {
        0.033245,     0.0659162217, 0.0636705814,
        0.0598194658, 0.0546642566, 0.0485871646,
        0.0420045997, 0.0353207015, 0.0288880982,
        0.0229808311, 0.0177815511, 0.013382297,
        0.0097960001, 0.0069746748, 0.0048301008,
        0.0032534598, 0.0021315311, 0.0013582974
    };

    color *= kernel[0];

    [loop]
    for(int i = 1; i < 18; ++i)
    {
        color += tex2D(SamplerColor, coord + float2(offset[i] * BUFFER_PIXEL_SIZE.x, 0.0)).rgb * kernel[i];
        color += tex2D(SamplerColor, coord - float2(offset[i] * BUFFER_PIXEL_SIZE.x, 0.0)).rgb * kernel[i];
    }

    return color;
}

float3 BlurV (float3 color, sampler SamplerColor, float2 coord)
{
    float offset[18] =
    {
        0.0,            1.4953705027, 3.4891992113,
        5.4830312105,   7.4768683759, 9.4707125766,
        11.4645656736, 13.4584295168, 15.4523059431,
        17.4461967743, 19.4661974725, 21.4627427973,
        23.4592916956, 25.455844494,  27.4524015179,
        29.4489630909, 31.445529535,  33.4421011704
    };

    float kernel[18] =
    {
        0.033245,     0.0659162217, 0.0636705814,
        0.0598194658, 0.0546642566, 0.0485871646,
        0.0420045997, 0.0353207015, 0.0288880982,
        0.0229808311, 0.0177815511, 0.013382297,
        0.0097960001, 0.0069746748, 0.0048301008,
        0.0032534598, 0.0021315311, 0.0013582974
    };

    color *= kernel[0];

    [loop]
    for(int i = 1; i < 18; ++i)
    {
        color += tex2D(SamplerColor, coord + float2(0.0, offset[i] * BUFFER_PIXEL_SIZE.y)).rgb * kernel[i];
        color += tex2D(SamplerColor, coord - float2(0.0, offset[i] * BUFFER_PIXEL_SIZE.y)).rgb * kernel[i];
    }

    return color;
}


// SHADERS /////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
#define PS_IN(v, c) float4 v : SV_Position, float2 c : TEXCOORD // Laziness macros FTW

// COPY BACKBUFFER ///////////////////////////////
void PS_Copy(PS_IN(vpos, coord), out float3 color : SV_Target)
{
    color  = tex2D(TextureColor, coord).rgb;
}

// CHECK DEPTH BUFFER ////////////////////////////
void PS_CopyDepth(PS_IN(vpos, coord), out float3 color : SV_Target)
{
    color  = ReShade::GetLinearizedDepth(coord);
}

// RESTORE BACKBUFFER ////////////////////////////
void PS_Restore(PS_IN(vpos, coord), out float3 color : SV_Target)
{
    color  = tex2D(TextureCopy, coord).rgb;
}

// IMAGE PREP
void PS_Prep(PS_IN(vpos, coord), out float3 color : SV_Target)
{
    float depth, sky;
    float3 tint;
    color  = tex2D(TextureColor, coord).rgb;
    depth  = ReShade::GetLinearizedDepth(coord);
    sky    = all(1-depth);

    // Fog density setting (gamma controls how thick the fog is)
    depth  = pow(abs(depth), lerp(10.0, 0.75, DISTANCE * 0.01));

    // Desaturate slightly with distance
    color  = lerp(color, lerp(GetLuma(color), color, 0.75), depth);

    // Overlay fog color to the scene before blurring in next step.
    // Additional masking for highlight protection. Code is a mess, I know.
    color  = lerp(color, min(max(FOG_TINT, 0.125), 1.0), depth * (1-smoothstep(0.0, 1.0, color) * (smoothstep(1.0, lerp(0.5, lerp(1.0, 0.75, DISTANCE * 0.01), HIGHLIGHT_DIST * 0.01), depth))));
                         // Avoid black fog                      // Protect highlights using smoothstep on color input, then place the highlights in the scene with a second smoothstep depth mask (this avoids the original sky color bleeding in)
}

// SCALE DOWN ////////////////////////////////////
void PS_Downscale1(PS_IN(vpos, coord), out float3 color : SV_Target)
{
    color  = tex2D(TextureColor, SCALE(coord, 0.5)).rgb;
}

void PS_Downscale2(PS_IN(vpos, coord), out float3 color : SV_Target)
{
    color  = tex2D(TextureColor, SCALE(coord, 0.125)).rgb;
}

// BI-LATERAL GAUSSIAN BLUR //////////////////////
void PS_BlurH(PS_IN(vpos, coord), out float3 color : SV_Target)
{
    color  = tex2D(TextureBlur1, coord).rgb;
    color  = BlurH(color, TextureBlur1, coord);
}
void PS_BlurV(PS_IN(vpos, coord), out float3 color : SV_Target)
{
    color  = tex2D(TextureBlur2, coord).rgb;
    color  = BlurV(color, TextureBlur2, coord);
}

// SCALE UP //////////////////////////////////////
void PS_UpScale1(PS_IN(vpos, coord), out float3 color : SV_Target)
{
    color  = tex2Dbicub(TextureBlur1, SCALE(coord, 2.0)).rgb;
}

void PS_UpScale2(PS_IN(vpos, coord), out float3 color : SV_Target)
{
    color  = tex2Dbicub(TextureBlur1, SCALE(coord, 8.0)).rgb;
}

// DRAW FOG //////////////////////////////////////
void PS_Combine(PS_IN(vpos, coord), out float3 color : SV_Target)
{
    float3 orig, blur, blur2, tint;
    float depth, depth_avg, sky;

    blur      = tex2D(TextureBlur2, coord).rgb;
    blur2     = tex2D(TextureColor, coord).rgb;
    color     = tex2D(TextureCopy,  coord).rgb;
    depth     = ReShade::GetLinearizedDepth(coord);
    sky       = all(1-depth);
    depth_avg = avGen::get();
    orig      = color;


    // Fog density setting (gamma controls how thick the fog is)
    depth     = pow(abs(depth), lerp(10.0, 0.33, DISTANCE * 0.01));

    // Use small blur texture to decrease distant detail
    color     = lerp(color, blur2, depth);

    // Darken the already dark parts of the image to give an impression of "shadowing" from fog using the large blur texture
    // Blending this way avoids extra dark halos on bright areas like the sky
    color     = lerp(color, lerp(color * pow(abs(blur), 10.0), color, color), depth * saturate(1-GetLuma(color * 0.75)) * sky);

    // Overlay the blur texture while lifting its gamma.
    // Mask protects highlights from being darkened
    color     = lerp(color, pow(abs(blur), 0.75), depth * saturate(1-GetLuma(color * 0.75)));

    // Do some additive blending to give the impression of scene lights affecting the fog
    color     = lerp(color, (color + pow(abs(blur), 0.5)) * 0.5, depth);

    // Dither to kill any banding
    color    += Dither(color, coord, BitDepth);

    if ((depth_avg == 0.0) || (depth_avg == 1.0))
    color     = orig;
}


// TECHNIQUES //////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
TECHNIQUE    (AtmosphericDensity,   "Atmospheric Density",
             "Atmospheric Density is a psuedo-volumetric\n"
             "fog shader. You will likely need to adjust\n"
             "the fog color to match your scene.",
    PASS_RT  (VS_Tri, PS_Copy,       TexCopy)  // Copy the backbuffer
    PASS     (VS_Tri, PS_CopyDepth)            // Write the depth buffer to backbuffer
    PASS_AVG ()                                // Generate avgerage depth buffer luma (This helps detect when depth is blank in menus in certain games)
    PASS     (VS_Tri, PS_Restore)              // Restore original backbuffer
    PASS     (VS_Tri, PS_Prep)                 // Prepare the backbuffer for blurring
    PASS_RT  (VS_Tri, PS_Downscale1, TexBlur1) // Downscale by 50%
    PASS     (VS_Tri, PS_UpScale1)             // Upscale back to 100% with bi-cubic filtering (this is the small blur)
    PASS_RT  (VS_Tri, PS_Downscale2, TexBlur1) // Scale down prepped backbuffer from above to 12.5%
    PASS_RT  (VS_Tri, PS_BlurH,      TexBlur2) // Blur horizontally
    PASS_RT  (VS_Tri, PS_BlurV,      TexBlur1) // Blur vertically
    PASS_RT  (VS_Tri, PS_UpScale2,   TexBlur2) // Scale back up to 100% size
    PASS     (VS_Tri, PS_Combine))             // Blend the blurred data and original backbuffer using depth
