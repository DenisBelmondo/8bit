version "4.8"

class EightBitHandler : StaticEventHandler
{
    override void RenderOverlay(RenderEvent e)
    {
        let palPP = CVar.GetCVar('pal_pp').GetInt();
        let palMode = CVar.GetCVar('pal_mode').GetInt();
        let palSet = CVar.GetCVar('pal_set').GetInt();
        let palSqSize = CVar.GetCVar('pal_sqsize').GetInt();
        let palBias = CVar.GetCVar('pal_bias').GetFloat();
        let palBlendMode = CVar.GetCVar('pal_blend_mode').GetInt();
        let palBlendAmount = CVar.GetCVar('pal_blend_amount').GetFloat();

        PPShader.SetEnabled("8bitBeforeBloom", palMode && palPP == 0);
        PPShader.SetEnabled("8bitScene", palMode && palPP == 1);
        PPShader.SetEnabled("8bitScreen", palMode && palPP == 2);

        PPShader.SetUniform1i("8bitBeforeBloom", "c_mode", palMode);
        PPShader.SetUniform1i("8bitBeforeBloom", "c_set", palSet);
        PPShader.SetUniform1i("8bitBeforeBloom", "c_sqsize", palSqSize);
        PPShader.SetUniform1f("8bitBeforeBloom", "c_bias", palBias);
        PPShader.SetUniform1f("8bitBeforeBloom", "c_blend_mode", palBlendMode);
        PPShader.SetUniform1f("8bitBeforeBloom", "c_blend_amount", palBlendAmount);

        PPShader.SetUniform1i("8bitScene", "c_mode", palMode);
        PPShader.SetUniform1i("8bitScene", "c_set", palSet);
        PPShader.SetUniform1i("8bitScene", "c_sqsize", palSqSize);
        PPShader.SetUniform1f("8bitScene", "c_bias", palBias);
        PPShader.SetUniform1f("8bitScene", "c_blend_mode", palBlendMode);
        PPShader.SetUniform1f("8bitScene", "c_blend_amount", palBlendAmount);

        PPShader.SetUniform1i("8bitScreen", "c_mode", palMode);
        PPShader.SetUniform1i("8bitScreen", "c_set", palSet);
        PPShader.SetUniform1i("8bitScreen", "c_sqsize", palSqSize);
        PPShader.SetUniform1f("8bitScreen", "c_bias", palBias);
        PPShader.SetUniform1f("8bitScreen", "c_blend_mode", palBlendMode);
        PPShader.SetUniform1f("8bitScreen", "c_blend_amount", palBlendAmount);
    }
}
