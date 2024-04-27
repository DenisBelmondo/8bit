// Copyright 2022 Rachael Alexanderson
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


vec3 paldownmix(vec3 color)
{
	ivec3 c = ivec3(clamp(color.rgb, vec3(0.0), vec3(1.0)) * 63.0 + 0.5);
	int index = (c.r * 64 + c.g) * 64 + c.b;
	int tx = index % 512;
	int ty = index / 512;
	return texelFetch(tclut, ivec2(tx, ty), 0).rgb;
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
		return vec4(paldownmix(c.rgb), 1.0);
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
