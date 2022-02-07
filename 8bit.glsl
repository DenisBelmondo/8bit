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


vec4 downmix(vec4 c)
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

vec4 dither1(vec4 c)
{
	return downmix(clamp(c * vec4(vec3(2.0), 1.0) - downmix(c), vec4(0.0, 0.0, 0.0, 0.0), vec4(1.0, 1.0, 1.0, 1.0)));
}

vec4 dither2(vec4 c)
{
	return downmix(clamp(c * vec4(vec3(2.0), 1.0) - dither1(c), vec4(0.0, 0.0, 0.0, 0.0), vec4(1.0, 1.0, 1.0, 1.0)));
}

vec4 dither3(vec4 c)
{
	return downmix(clamp(c * vec4(vec3(2.0), 1.0) - dither2(c), vec4(0.0, 0.0, 0.0, 0.0), vec4(1.0, 1.0, 1.0, 1.0)));
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
			FragColor = dither1(c);
		else
			FragColor = downmix(c);
		break;
	case 3:
		int pos = (int(txc.x) & 1) + (int(txc.y) & 1) * 2;
		switch (pos)
		{
		default:
		case 0:
			FragColor = downmix(c);
			break;
		case 1:
			FragColor = dither1(c);
			break;
		case 3:
			FragColor = dither2(c);
			break;
		case 2:
			FragColor = dither3(c);
			break;
		}		
		break;
	case 4:
		vec4 o1 = c;
		vec4 o2 = downmix(c);
		vec4 o3 = dither1(c);

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
			vec4 o4 = (downmix(c) * dd3 + dither1(c) * dd2) / (dd2 + dd3);
			float bri4 = max(brightness(vec3(o4)), 0.0001);
			FragColor = o4 * bri1 / bri4;
		}
	}
}

