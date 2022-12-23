version "4.0"

class EightBitHandler : StaticEventHandler
{
    override void RenderOverlay(RenderEvent e)
    {
        let p = players[consolePlayer];

        let palPP = CVar.GetCVar('pal_pp').GetInt();
        let palMode = CVar.GetCVar('pal_mode').GetInt();
        let palSet = CVar.GetCVar('pal_set').GetInt();
        let palSqSize = CVar.GetCVar('pal_sqsize').GetInt();
        let palBias = CVar.GetCVar('pal_bias').GetFloat();

        Shader.SetEnabled(p, "8bitBeforeBloom", palPP == 0);
        Shader.SetEnabled(p, "8bitScene", palPP == 1);
        Shader.SetEnabled(p, "8bitScreen", palPP == 2);

        Shader.SetUniform1i(p, "8bitBeforeBloom", "c_mode", palMode);
        Shader.SetUniform1i(p, "8bitBeforeBloom", "c_set", palSet);
        Shader.SetUniform1i(p, "8bitBeforeBloom", "c_sqsize", palSqSize);
        Shader.SetUniform1f(p, "8bitBeforeBloom", "c_bias", palBias);

        Shader.SetUniform1i(p, "8bitScene", "c_mode", palMode);
        Shader.SetUniform1i(p, "8bitScene", "c_set", palSet);
        Shader.SetUniform1i(p, "8bitScene", "c_sqsize", palSqSize);
        Shader.SetUniform1f(p, "8bitScene", "c_bias", palBias);

        Shader.SetUniform1i(p, "8bitScreen", "c_mode", palMode);
        Shader.SetUniform1i(p, "8bitScreen", "c_set", palSet);
        Shader.SetUniform1i(p, "8bitScreen", "c_sqsize", palSqSize);
        Shader.SetUniform1f(p, "8bitScreen", "c_bias", palBias);
    }
}
