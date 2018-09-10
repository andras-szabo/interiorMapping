Shader "Unlit/FakeInterior_MultipleRooms"
{
	Properties
	{
		_MainTex("Window frame", 2D) = "white" {}	

		_Ceiling("Ceiling", 2D) = "white" {}
		_Floor("Floor", 2D) = "white" {}
		_Backwall("Back wall", 2D) = "white" {}
		_Leftwall("Left wall", 2D) = "white" {}
		_Rightwall("Right wall", 2D) = "white" {}

		_HDivision("HDivision", float) = 1.0
		_VDivision("VDivision", float) = 1.0

	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
				float4 fragmentInObjectSpace : TEXCOORD1;
				float3 cameraInObjectSpace : TEXCOORD2;
			};

			sampler2D _Floor;
			sampler2D _Ceiling;
			sampler2D _Backwall;
			sampler2D _Leftwall;
			sampler2D _Rightwall;
			sampler2D _MainTex;
			float4 _MainTex_ST;
			float _HDivision;
			float _VDivision;
			
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.fragmentInObjectSpace = v.vertex + float4(0.5, 0.5, 0, 0);
				o.cameraInObjectSpace = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1.0)) + float3(0.5, 0.5, 0);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				float3 cameraToFragment = i.fragmentInObjectSpace - i.cameraInObjectSpace;
				
				// wallDistances = (floor(i.fragmentInObjectSpace * dv) + step(float2(0, 0), cameraToFragment)) / dv;
				// is equivalent to the following:
				// wallDistances.x = (floor(i.fragmentInObjectSpace.x * _HDivision) + step(0, cameraToFragment.x)) / _HDivision;
				// wallDistances.y = (floor(i.fragmentInObjectSpace.y * _VDivision) + step(0, cameraToFragment.y)) / _VDivision;
				//
				// which is further equivalent to:
				// finding the length or width of a room (1 / _HDivision) or (1 / _VDivision), and then finding the
				// number of walls up to current fragment position (plus one, if the ray we're tracing is headed to the right)

				float2 roomCount = float2(_HDivision, _VDivision);
				float2 wallDistances = (floor(i.fragmentInObjectSpace * roomCount) + step(float2(0, 0), cameraToFragment)) / roomCount;
				float3 wallPositions = float3(wallDistances.x, wallDistances.y, 1.0);

				float3 rayFractions = (wallPositions - i.cameraInObjectSpace) / cameraToFragment;

				float2 intersectionXY = (i.cameraInObjectSpace + rayFractions.z * cameraToFragment).xy * float2(roomCount.x, roomCount.y);
				float2 intersectionXZ = (i.cameraInObjectSpace + rayFractions.y * cameraToFragment).xz * float2(roomCount.x, 1);
				float2 intersectionZY = (i.cameraInObjectSpace + rayFractions.x * cameraToFragment).zy * float2(1, roomCount.y);

				fixed4 ceilingColor = tex2D(_Ceiling, intersectionXZ);
				fixed4 floorColor = tex2D(_Floor, intersectionXZ);

				// Is the camera looking up at the fragment? Then we hit the ceiling.
				// Otherwise, we hit the floor.
				fixed4 floorOrCeilingColor = lerp(floorColor, ceilingColor, step(0, cameraToFragment.y));

				fixed4 backWallColor = tex2D(_Backwall, intersectionXY);
				
				fixed4 leftWallColor = tex2D(_Leftwall, intersectionZY);
				fixed4 rightWallColor = tex2D(_Rightwall, float2(1 - intersectionZY.x, intersectionZY.y));
				fixed4 sideWallColor = lerp(leftWallColor, rightWallColor, step(0, cameraToFragment.x));

				float x_vs_z = step(rayFractions.x, rayFractions.z);
				fixed4 wallColor = lerp(backWallColor, sideWallColor, x_vs_z);

				float rayFraction_x_vs_z = lerp(rayFractions.z, rayFractions.x, x_vs_z);
				float x_z_vs_y = step(rayFraction_x_vs_z, rayFractions.y);

				fixed4 interiorCol = lerp(floorOrCeilingColor, wallColor, x_z_vs_y);
				fixed4 frameCol = tex2D(_MainTex, i.uv);

				fixed4 col = lerp(interiorCol, frameCol, step(0.2, frameCol.a));
				return col;
			}
			ENDCG
		}
	}
}
