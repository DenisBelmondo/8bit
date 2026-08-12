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


#define PI 3.14159265
#define TAU (PI*2.0)

//
// nmz@shadertoy/stormoid@twitter: cheaply find the shortest arc between two
// angles. https://www.shadertoy.com/view/lsdGzN
//

float shortestAng(in float a, in float b)
{
	float ang = mod(mod((a-b), TAU) + PI*3., TAU)-PI;
	return ang;
}

//
// DenisBelmondo: `dir` picks which way around the wheel the hue travels. The
// four rules are the ones CSS Color 4 defines for hue interpolation. "Longer"
// sweeps the whole wheel instead of taking the direct route.
//

float lerpHue(in float from, in float to, in float x, in int dir)
{
	float d = shortestAng(to, from);

	switch (dir)
	{
	case 1: // longer
		d -= sign(d)*TAU;
		break;
	case 2: // increasing
		if (d < 0.0)
			d += TAU;
		break;
	case 3: // decreasing
		if (d > 0.0)
			d -= TAU;
		break;
	}

	return from + d*x;
}

//
// DenisBelmondo: every space below is cylindrical, so we can express a color
// in any of them as a common (achromatic, chroma, hue) triple and blend each
// channel independently. `x` holds the per-channel blend amounts in the same
// order: 0.0 keeps `a`'s channel, 1.0 takes `b`'s.
//
// A neutral color has no meaningful hue -- atan(0, 0) is whatever the hardware
// feels like -- so a near-neutral side borrows the other's hue rather than
// blending toward noise. Its chroma is ~0, so this cannot tint anything.
//

#define ACHROMATIC 1.0e-4

vec3 blendCylindrical(in vec3 a, in vec3 b, in vec3 x, in int hueDir)
{
	float ha = a.y < ACHROMATIC ? b.z : a.z;
	float hb = b.y < ACHROMATIC ? a.z : b.z;
	return vec3(mix(a.x, b.x, x.x), mix(a.y, b.y, x.y), lerpHue(ha, hb, x.z, hueDir));
}

//
// The IEC 61966-2-1 transfer function. Everything that routes through XYZ --
// CIELAB, CIELUV, Oklab -- is defined on linear light and has to decode first.
// HSV, HSL and YIQ are defined on the encoded values and skip this.
//

vec3 sRGB_to_linear(in vec3 c)
{
	vec3 lo = c/12.92;
	vec3 hi = pow((c + 0.055)/1.055, vec3(2.4));
	return mix(lo, hi, greaterThan(c, vec3(0.04045)));
}

//
// Clamps on the way out: a channel blend can easily land outside the sRGB
// gamut, and pow() of a negative base is undefined.
//

vec3 linear_to_sRGB(in vec3 c)
{
	c = clamp(c, vec3(0.0), vec3(1.0));
	vec3 lo = c*12.92;
	vec3 hi = 1.055*pow(c, vec3(1.0/2.4)) - 0.055;
	return mix(lo, hi, greaterThan(c, vec3(0.0031308)));
}

//
// HSV, reordered to (value, saturation, hue) with the hue in radians so it
// lines up with LCh. The conversions themselves are the well-known branchless
// ones by Sam Hocevar.
//

vec3 sRGB_to_VSH(in vec3 c)
{
	vec4 K = vec4(0.0, -1.0/3.0, 2.0/3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(q.x, clamp(d/(q.x + e), 0.0, 1.0), abs(q.z + (q.w - q.y)/(6.0*d + e))*TAU);
}

vec3 VSH_to_sRGB(in vec3 VSH)
{
	vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
	vec3 p = abs(fract(VSH.zzz/TAU + K.xyz)*6.0 - K.www);
	return VSH.x * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), VSH.y);
}

//
// HSL, same hexcone but with lightness at the midpoint of the extremes rather
// than at the maximum channel. Holds up better than HSV on dark palettes.
//

vec3 sRGB_to_LSH(in vec3 c)
{
	vec4 K = vec4(0.0, -1.0/3.0, 2.0/3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float mn = min(q.w, q.y);
	float d = q.x - mn;
	float e = 1.0e-10;
	float L = (q.x + mn)*0.5;

	//
	// The saturation denominator is 1 - |2L - 1|, but written that way it loses
	// every significant digit as L approaches 0 or 1: measured over 6M colours it
	// let S reach 596, and on a driver that reassociates it can go negative and
	// send S to infinity. 2*min(L, 1 - L) is the same quantity with no
	// cancellation, and the clamp pins S to the range real RGB can produce.
	//
	// This matters at pure white, where the inverse computes C = (1 - |2L - 1|)*S
	// = 0*S. With S merely large that is 0 and the pixel stays white; with S
	// infinite it is NaN, and clamp(NaN) is 0 -- a black pixel.
	//
	float S = clamp(d/(2.0*min(L, 1.0 - L) + e), 0.0, 1.0);

	return vec3(L, S, abs(q.z + (q.w - q.y)/(6.0*d + e))*TAU);
}

vec3 LSH_to_sRGB(in vec3 LSH)
{
	vec3 K = vec3(1.0, 2.0/3.0, 1.0/3.0);
	vec3 p = abs(fract(LSH.zzz/TAU + K)*6.0 - 3.0);
	float C = 2.0*min(LSH.x, 1.0 - LSH.x)*LSH.y;
	return (clamp(p - 1.0, 0.0, 1.0) - 0.5)*C + LSH.x;
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
	return XYZ_to_Lab(sRGB_TO_XYZ_D50*sRGB_to_linear(sRGB), D50);
}

vec3 Lab_to_sRGB(vec3 Lab) {
	return linear_to_sRGB(XYZ_D50_TO_sRGB*Lab_to_XYZ(Lab, D50));
}

vec3 sRGB_to_LCh(vec3 sRGB) {
	return Lab_to_LCh(sRGB_to_Lab(sRGB));
}

vec3 LCh_to_sRGB(vec3 LCh) {
	return Lab_to_sRGB(LCh_to_Lab(LCh));
}

// OkLCh <-> Oklab <-> linear sRGB

//
// Bjorn Ottosson, https://bottosson.github.io/posts/oklab/ -- CIELAB has a
// pronounced hue kink in the blues (change the lightness of a saturated blue
// and it drifts purple), which a Doom palette runs into constantly. Oklab is
// built to hold hue steady, and costs one matrix, a cube root, one matrix.
//
// mat3 constructors take COLUMNS, so each line below is one input channel's
// coefficients, not one output channel's.
//

const mat3 LINEAR_TO_LMS = mat3(
	0.4122214708, 0.2119034982, 0.0883024619,
	0.5363325363, 0.6806995451, 0.2817188376,
	0.0514459929, 0.1073969566, 0.6299787005);

const mat3 LMS_TO_LINEAR = mat3(
	 4.0767416621, -1.2684380046, -0.0041960863,
	-3.3077115913,  2.6097574011, -0.7034186147,
	 0.2309699292, -0.3413193965,  1.7076147010);

const mat3 LMS3_TO_OKLAB = mat3(
	 0.2104542553,  1.9779984951,  0.0259040371,
	 0.7936177850, -2.4285922050,  0.7827717662,
	-0.0040720468,  0.4505937099, -0.8086757660);

const mat3 OKLAB_TO_LMS3 = mat3(
	1.0,  1.0,  1.0,
	0.3963377774, -0.1055613458, -0.0894841775,
	0.2158037573, -0.0638541728, -1.2914855480);

vec3 sRGB_to_OkLCh(vec3 sRGB) {
	vec3 lms = LINEAR_TO_LMS*sRGB_to_linear(sRGB);
	vec3 Lab = LMS3_TO_OKLAB*(sign(lms)*pow(abs(lms), vec3(1.0/3.0)));
	return vec3(Lab.x, length(Lab.yz), atan(Lab.z, Lab.y));
}

vec3 OkLCh_to_sRGB(vec3 LCh) {
	vec3 lms = OKLAB_TO_LMS3*vec3(LCh.x, LCh.y*vec2(cos(LCh.z), sin(LCh.z)));
	return linear_to_sRGB(LMS_TO_LINEAR*(lms*lms*lms));
}

// LCh(uv) ↔ Luv ↔ XYZ ↔ sRGB

//
// DenisBelmondo: Luv's chroma is additive -- mixing two colors stays on the
// straight chromaticity line between them -- so blending chroma here reads as
// a clean desaturation toward the palette rather than a curved detour. More
// vivid than LCh(ab) on the way.
//

vec2 XYZ_to_uv(vec3 XYZ) {
	float d = XYZ.x + 15.0*XYZ.y + 3.0*XYZ.z;
	return vec2(4.0, 9.0)*XYZ.xy/max(d, 1.0e-10);
}

vec3 XYZ_to_Luv(vec3 XYZ, vec3 XYZw) {
	float Y = XYZ.y/XYZw.y;
	float L = Y > 216.0/24389.0 ? 1.16*pow(Y, 1.0/3.0) - 0.16 : 24389.0/2700.0*Y;
	return vec3(L, 13.0*L*(XYZ_to_uv(XYZ) - XYZ_to_uv(XYZw)));
}

vec3 Luv_to_XYZ(vec3 Luv, vec3 XYZw) {
	if (Luv.x <= 0.0)
		return vec3(0.0);

	vec2 uv = Luv.yz/(13.0*Luv.x) + XYZ_to_uv(XYZw);
	float Y = Luv.x > 0.08 ? pow((Luv.x + 0.16)/1.16, 3.0) : 2700.0/24389.0*Luv.x;
	float d = max(4.0*uv.y, 1.0e-10);
	float X = 9.0*uv.x/d;
	float Z = (12.0 - 3.0*uv.x - 20.0*uv.y)/d;
	return XYZw.y*vec3(Y*X, Y, Y*Z);
}

vec3 sRGB_to_LChuv(vec3 sRGB) {
	vec3 Luv = XYZ_to_Luv(sRGB_TO_XYZ_D65*sRGB_to_linear(sRGB), D65);
	return vec3(Luv.x, length(Luv.yz), atan(Luv.z, Luv.y));
}

vec3 LChuv_to_sRGB(vec3 LCh) {
	vec3 Luv = vec3(LCh.x, LCh.y*vec2(cos(LCh.z), sin(LCh.z)));
	return linear_to_sRGB(XYZ_D65_TO_sRGB*Luv_to_XYZ(Luv, D65));
}

// YIQ ↔ sRGB

//
// DenisBelmondo: the NTSC transmission space, on gamma-encoded values and not
// perceptually uniform at all -- which is the point. Its I axis is the
// orange/cyan "flesh tone line" broadcast engineers picked on purpose, so hue
// blending in YIQ leans toward skin tones and away from greens the way analog
// video did.
//

const mat3 sRGB_TO_YIQ = mat3(
	0.299,  0.5959,  0.2115,
	0.587, -0.2746, -0.5227,
	0.114, -0.3213,  0.3112);

const mat3 YIQ_TO_sRGB = mat3(
	1.0, 1.0, 1.0,
	0.9560502264, -0.2720523437, -1.1067043153,
	0.6207549413, -0.6472057135,  1.7044212837);

vec3 sRGB_to_YCh(vec3 sRGB) {
	vec3 YIQ = sRGB_TO_YIQ*sRGB;
	return vec3(YIQ.x, length(YIQ.yz), atan(YIQ.z, YIQ.y));
}

vec3 YCh_to_sRGB(vec3 YCh) {
	return YIQ_TO_sRGB*vec3(YCh.x, YCh.y*vec2(cos(YCh.z), sin(YCh.z)));
}

//
// The blend spaces, indexed by c_blend_space. Each pair maps sRGB to and from
// a cylindrical (achromatic, chroma, hue) triple with the hue in radians, so
// blendCylindrical() does not care which one it was handed.
//

vec3 sRGB_to_cyl(vec3 c, int space)
{
	switch (space)
	{
	default:
	case 0:
		return sRGB_to_VSH(c);
	case 1:
		return sRGB_to_LCh(c);
	case 2:
		return sRGB_to_OkLCh(c);
	case 3:
		return sRGB_to_LChuv(c);
	case 4:
		return sRGB_to_YCh(c);
	case 5:
		return sRGB_to_LSH(c);
	}
}

vec3 cyl_to_sRGB(vec3 v, int space)
{
	switch (space)
	{
	default:
	case 0:
		return VSH_to_sRGB(v);
	case 1:
		return LCh_to_sRGB(v);
	case 2:
		return OkLCh_to_sRGB(v);
	case 3:
		return LChuv_to_sRGB(v);
	case 4:
		return YCh_to_sRGB(v);
	case 5:
		return LSH_to_sRGB(v);
	}
}

//
// DenisBelmondo: index with integers, not floats.
//
// The float form this replaced is correct in IEEE float32 -- 65536*b is exactly
// representable, 4096 is a power of two, and every floor() lands on the right
// integer -- but it does not survive real drivers. Measured against a probe
// sweep, pure blues above roughly b=111 fetched a texel from somewhere else
// entirely and came back violet, while the identical lookup indexed with ints
// was correct for all 256 values. Red and green never showed it because their
// lut values stay small; blue reaches 16.7 million.
//

vec4 paldownmix(vec4 c)
{
	ivec3 q = ivec3(clamp(c.rgb, vec3(0.0), vec3(1.0))*255.0 + 0.5);

	int lut = q.b*65536 + q.g*256 + q.r;
	int cy = lut/4096;
	int cx = lut - cy*4096;

	return texture(tclut, (vec2(cx, cy) + 0.5)/4096.0);
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
	{
		vec4 o1 = c;
		vec4 o2 = downmix(c);
		vec4 o3 = dither(c, 1);

		float bri1 = max(brightness(vec3(o1)), 0.0001);
		float bri2 = max(brightness(vec3(o2)), 0.0001);
		float bri3 = max(brightness(vec3(o3)), 0.0001);

		vec3 d2 = vec3(abs(o1 - o2));
		vec3 d3 = vec3(abs(o1 - o3));

		float dd2 = d2.r + d2.g + d2.b;
		float dd3 = d3.r + d3.g + d3.b;

		if (dd2 + dd3 <= 0.0)
			FragColor = o2 * bri1 / bri2;
		else
		{
			vec4 o4 = (o2 * dd3 + o3 * dd2) / (dd2 + dd3);
			float bri4 = max(brightness(vec3(o4)), 0.0001);
			FragColor = o4 * bri1 / bri4;
		}

		break;
	}
	case 5:
	{
		// Per-channel blend amounts, ordered to match the cylindrical triple:
		// (value/lightness/luminance, saturation/chroma, hue).
		vec3 amount = vec3(c_blend_lum, c_blend_sat, c_blend_hue);

		vec3 orig = sRGB_to_cyl(c.rgb, c_blend_space);
		vec3 downmixed = sRGB_to_cyl(downmix(c).rgb, c_blend_space);
		vec3 blended = blendCylindrical(orig, downmixed, amount, c_hue_dir);

		FragColor = vec4(clamp(cyl_to_sRGB(blended, c_blend_space), vec3(0.0), vec3(1.0)), c.a);

		break;
	}
	}
}

