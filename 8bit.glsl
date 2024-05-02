// Copyright 2022-2024 Rachael Alexanderson, DenisBelmondo
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice,
//    this list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its
//    contributors may be used to endorse or promote products derived from this
//    software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.


#define PI 3.14159365
#define TAU 6.28318531

//
// nmz@shadertoy/stormoid@twitter: cheaply lerp around a circle
// https://www.shadertoy.com/view/lsdGzN
//

float lerpAng(in float a, in float b, in float x)
{
    float ang = mod(mod((a-b), TAU) + PI*3., TAU)-PI;
    return ang*x+b;
}

//
// DenisBelmondo: these are loosely modified versions of the lerp
// @nmz/@stormoid implemented.
//

vec3 lerpLchColor(in vec3 a, in vec3 b, in float x)
{
    float hue = lerpAng(b.z, a.z, x);
	float chroma = lerpAng(b.y, a.y, x);
    return vec3(a.x, chroma, hue);
}

vec3 lerpLchChroma(in vec3 a, in vec3 b, in float x)
{
	float chroma = lerpAng(b.y, a.y, x);
	return vec3(a.x, chroma, a.z);
}

vec3 lerpLchHue(in vec3 a, in vec3 b, in float x)
{
	float hue = lerpAng(b.z, a.z, x);
	return vec3(a.x, a.y, hue);
}

#define diag3(v) mat3((v).x, 0.0, 0.0, 0.0, (v).y, 0.0, 0.0, 0.0, (v).z)
#define xyY_to_XYZ(x, y, Y) vec3(Y/y*x, Y, Y/y*(1.0 - x - y))
#define xy_to_XYZ(x, y) vec3(x/y, 1.0, (1.0 - x - y)/y)
#define xy_to_xyz(x, y) vec3(x, y, 1.0 - x - y)

mat3 BFD;

vec3 D50;
vec3 D65;
mat3 D65_TO_D50;

mat3 sRGB;
mat3 sRGB_TO_XYZ_D65;
mat3 sRGB_TO_XYZ_D50;
mat3 XYZ_D65_TO_sRGB;
mat3 XYZ_D50_TO_sRGB;

// LCh(ab) ↔ Lab ↔ XYZ ↔ sRGB

vec3 XYZ_to_Lab(vec3 XYZ, vec3 XYZw) {
	vec3 t = XYZ/XYZw;
	vec3 a = pow(t, vec3(1.0/3.0));
	vec3 b = 841.0/108.0*t + 4.0/29.0;
	vec3 c = mix(b, a, greaterThan(t, vec3(216.0/24389.0)));
	return vec3(1.16*c.y - 0.16, vec2(5.0, 2.0)*(c.xy - c.yz));
}

vec3 Lab_to_XYZ(vec3 Lab, vec3 XYZw) {
	float L = (Lab.x + 0.16)/1.16;
	vec3 t = vec3(L + Lab.y/5.0, L, L - Lab.z/2.0);
	vec3 a = pow(t, vec3(3.0));
	vec3 b = 108.0/841.0*(t - 4.0/29.0);
	return XYZw*mix(b, a, greaterThan(t, vec3(6.0/29.0)));
}

vec3 LCh_to_Lab(vec3 LCh) {
	return vec3(LCh.x, LCh.y*vec2(cos(LCh.z), sin(LCh.z)));
}

vec3 Lab_to_LCh(vec3 Lab) {
	return vec3(Lab.x, length(Lab.yz), atan(Lab.z, Lab.y));
}

vec3 sRGB_to_Lab(vec3 sRGB) {
	return XYZ_to_Lab(sRGB_TO_XYZ_D50*sRGB, D50);
}

vec3 Lab_to_sRGB(vec3 Lab) {
	return XYZ_D50_TO_sRGB*Lab_to_XYZ(Lab, D50);
}

// LCh(uv) ↔ Luv ↔ XYZ ↔ sRGB

//
// DenisBelmondo:
// TODO: implement LUV blending later???
//

/*
	#define XYZ_to_uv(XYZ) vec2(4.0, 9.0)*XYZ.xy/(XYZ.x + 15.0*XYZ.y + 3.0*XYZ.z)
	#define xy_to_uv(xy) vec2(4.0, 9.0)*xy/(-2.0*xy.x + 12.0*xy.y + 3.0)
	#define uv_to_xy(uv) vec2(9.0, 4.0)*uv/(6.0*uv.x - 16.0*uv.y + 12.0)

	vec3 XYZ_to_Luv(vec3 XYZ, vec3 XYZw) {
		float Y = XYZ.y/XYZw.y;
		float L = Y > 216.0/24389.0 ? 1.16*pow(Y, 1.0/3.0) - 0.16 : 24389.0/2700.0*Y;
		return vec3(L, 13.0*L*(XYZ_to_uv(XYZ) - XYZ_to_uv(XYZw)));
	}

	vec3 Luv_to_XYZ(vec3 Luv, vec3 XYZw) {
		vec2 uv = Luv.yz/(13.0*Luv.x) + XYZ_to_uv(XYZw);
		float Y = Luv.x > 0.08 ? pow((Luv.x + 0.16)/1.16, 3.0) : 2700.0/24389.0*Luv.x;
		float X = (9.0*uv.x)/(4.0*uv.y);
		float Z = (12.0 - 3.0*uv.x - 20.0*uv.y)/(4.0*uv.y);
		return XYZw.y*vec3(Y*X, Y, Y*Z);
	}

	vec3 LCh_to_Luv(vec3 LCh) {
		return vec3(LCh.x, LCh.y*vec2(cos(LCh.z), sin(LCh.z)));
	}

	vec3 Luv_to_LCh(vec3 Luv) {
		return vec3(Luv.x, length(Luv.yz), atan(Luv.z, Luv.y));
	}

	vec3 sRGB_to_Luv(vec3 sRGB) {
		return XYZ_to_Luv(sRGB_TO_XYZ_D65*sRGB, D65);
	}

	vec3 Luv_to_sRGB(vec3 Luv) {
		return XYZ_D65_TO_sRGB*Luv_to_XYZ(Luv, D65);
	}
*/

vec4 paldownmix(vec4 c)
{
	float cr = floor(c.r * 255.0);
	float cg = floor(c.g * 255.0);
	float cb = floor(c.b * 255.0);

	float lut = cb * 65536.0 + cg * 256.0 + cr * 1.0;
	float cy = floor(lut / 4096.0);
	float cx = lut - cy * 4096.0;

	float tx = (cx + .5) / 4096.0;
	float ty = (cy + .5) / 4096.0;
	return texture(tclut, vec2(tx, ty));
}

vec4 fbdownmix(vec4 c, sampler2D fblut)
{
	float fdiff = 3.0;
	float fattr = 0;
	for (int i = 0; i < 16; i++)
	{
		vec3 lu = abs(pow(vec3(texture(fblut, vec2((i + 0.5) / 16, 0.5))), vec3(2.2)) - pow(vec3(c), vec3(2.2)));
		float diff = lu.r + lu.g + lu.b;
		if (fdiff > diff)
		{
			fdiff = diff;
			fattr = float(i);
		}
	}
	return texture(fblut, vec2((fattr + 0.5) / 16.0, 0.5));
}

vec4 hiegadownmix(vec4 c)
{
	vec3 h = vec3(c);
	h = floor(h * 255.0 / 256.0 * 4.0) / 3.0;
	return vec4(h, c.a);
}

vec4 downmix(vec4 c)
{
	switch (c_set)
	{
	default:
	case 0:
		return paldownmix(c);
	case 1:
		return hiegadownmix(c);
	case 2:
		return fbdownmix(c, egalut);
	case 3:
		return fbdownmix(c, winlut);
	case 4:
		return fbdownmix(c, maclut);
	}
}

vec4 dither(vec4 c, int count)
{
	vec4 r = c;
	for (; count>=0; count--)
	{
		r = r + (c - downmix(clamp(r, vec4(0.0, 0.0, 0.0, 0.0), vec4(1.0, 1.0, 1.0, 1.0)))) * c_bias;
	}
	r = downmix(clamp(r, vec4(0.0, 0.0, 0.0, 0.0), vec4(1.0, 1.0, 1.0, 1.0)));
	return r;
}

float brightness(vec3 c)
{
	return pow(dot(pow(vec3(c), vec3(2.2)), vec3(0.2126, 0.7152, 0.0722)), 1.0/2.2);
}

void main()
{
	vec4 c = clamp(texture(InputTexture, TexCoord), vec4(0.0, 0.0, 0.0, 0.0), vec4(1.0, 1.0, 1.0, 1.0));

	vec2 txc = TexCoord * textureSize(InputTexture, 0);

	BFD = mat3(0.8951, -0.7502, 0.0389, 0.2664, 1.7135, -0.0685, -0.1614, 0.0367, 1.0296);

	D50 = xy_to_XYZ(0.34567, 0.35850);
	D65 = xy_to_XYZ(0.31271, 0.32902);
	D65_TO_D50 = inverse(BFD)*diag3((BFD*D50)/(BFD*D65))*BFD;

	sRGB = mat3(xy_to_XYZ(0.64, 0.33), xy_to_XYZ(0.30, 0.60), xy_to_XYZ(0.15, 0.06));
	sRGB_TO_XYZ_D65 = sRGB*diag3(inverse(sRGB)*D65);
	sRGB_TO_XYZ_D50 = D65_TO_D50*sRGB_TO_XYZ_D65;
	XYZ_D65_TO_sRGB = inverse(sRGB_TO_XYZ_D65);
	XYZ_D50_TO_sRGB = inverse(sRGB_TO_XYZ_D50);

	switch (c_mode)
	{
	default:
	case 0:
		FragColor = texture(InputTexture, TexCoord);
		break;
	case 1:
		FragColor = downmix(c);
		break;
	case 2:
		bool checker = ((int(txc.x) + int(txc.y)) & 1) == 1;

		if (checker)
			FragColor = dither(c, 1);
		else
			FragColor = downmix(c);
		break;
	case 3:
		if ((int(txc.y) & 1) == 1)
			txc.x = 1.0 - txc.x;

		int pos = (int(txc.x) % c_sqsize) + (int(txc.y) % c_sqsize) * c_sqsize;

		if (pos == 0)
			FragColor = downmix(clamp(c, vec4(0.0, 0.0, 0.0, 1.0), vec4(1.0, 1.0, 1.0, 1.0)));
		else
			FragColor = dither(clamp(c, vec4(0.0, 0.0, 0.0, 1.0), vec4(1.0, 1.0, 1.0, 1.0)), pos);

		break;
	case 4:
		vec4 o1 = c;
		vec4 o2 = downmix(c);

		if (c_blend_mode > 0)
		{
			vec3 comp;
			vec3 cLCH = Lab_to_LCh(sRGB_to_Lab(o1.rgb));
			vec3 downmixed = Lab_to_LCh(sRGB_to_Lab(o2.rgb));

			switch (c_blend_mode)
			{
			case 1:
				FragColor.rgb = Lab_to_sRGB(LCh_to_Lab(lerpLchColor(cLCH, downmixed, c_blend_amount)));
				break;
			case 2:
				FragColor.rgb = Lab_to_sRGB(LCh_to_Lab(lerpLchChroma(cLCH, downmixed, c_blend_amount)));
				break;
			case 3:
				FragColor.rgb = Lab_to_sRGB(LCh_to_Lab(lerpLchHue(cLCH, downmixed, c_blend_amount)));
				break;
			}
		}
		else
		{
			vec4 o3 = dither(c, 1);

			float bri1 = max(brightness(vec3(o1)), 0.0001);
			float bri2 = max(brightness(vec3(o2)), 0.0001);
			float bri3 = max(brightness(vec3(o3)), 0.0001);

			vec3 d2 = vec3(abs(o1 - o2));
			vec3 d3 = vec3(abs(o1 - o3));

			float dd2 = d2.r + d2.g + d2.b;
			float dd3 = d3.r + d3.g + d3.b;

			if (dd2 + dd3 <= 0.0)
				FragColor = downmix(c) * bri1 / bri2;
			else
			{
				vec4 o4 = (downmix(c) * dd3 + o3 * dd2) / (dd2 + dd3);
				float bri4 = max(brightness(vec3(o4)), 0.0001);
				FragColor = o4 * bri1 / bri4;
			}
		}
	}
}

