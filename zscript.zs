version "4.8"

class EightBitHandler : StaticEventHandler
{
    private ui static void UpdateShader(
        string shader,
        bool enabled,
        int mode,
        int set,
        int sqSize,
        double bias,
        int blendSpace,
        double blendHue,
        double blendSat,
        double blendLum,
        int hueDir)
    {
        PPShader.SetEnabled(shader, enabled);
        PPShader.SetUniform1i(shader, "c_mode", mode);
        PPShader.SetUniform1i(shader, "c_set", set);
        PPShader.SetUniform1i(shader, "c_sqsize", sqSize);
        PPShader.SetUniform1f(shader, "c_bias", bias);
        PPShader.SetUniform1i(shader, "c_blend_space", blendSpace);
        PPShader.SetUniform1f(shader, "c_blend_hue", blendHue);
        PPShader.SetUniform1f(shader, "c_blend_sat", blendSat);
        PPShader.SetUniform1f(shader, "c_blend_lum", blendLum);
        PPShader.SetUniform1i(shader, "c_hue_dir", hueDir);
    }

    override void RenderOverlay(RenderEvent e)
    {
        let palPP = CVar.GetCVar('pal_pp').GetInt();
        let palMode = CVar.GetCVar('pal_mode').GetInt();
        let palSet = CVar.GetCVar('pal_set').GetInt();
        let palSqSize = CVar.GetCVar('pal_sqsize').GetInt();
        let palBias = CVar.GetCVar('pal_bias').GetFloat();
        let palBlendSpace = CVar.GetCVar('pal_blend_space').GetInt();
        let palBlendHue = CVar.GetCVar('pal_blend_hue').GetFloat();
        let palBlendSat = CVar.GetCVar('pal_blend_sat').GetFloat();
        let palBlendLum = CVar.GetCVar('pal_blend_lum').GetFloat();
        let palHueDir = CVar.GetCVar('pal_blend_hue_dir').GetInt();

        for (int i = 0; i < 3; ++i)
        {
            string shader;

            switch (i)
            {
            case 0: shader = "8bitBeforeBloom"; break;
            case 1: shader = "8bitScene"; break;
            default: shader = "8bitScreen"; break;
            }

            UpdateShader(
                shader,
                palMode != 0 && palPP == i,
                palMode,
                palSet,
                palSqSize,
                palBias,
                palBlendSpace,
                palBlendHue,
                palBlendSat,
                palBlendLum,
                palHueDir);
        }
    }
}
