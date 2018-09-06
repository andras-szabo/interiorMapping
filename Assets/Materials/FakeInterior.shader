Shader "Unlit/FakeInterior"
{
	Properties
	{
		_MainTex("Window frame", 2D) = "white" {}	

		_Ceiling("Ceiling", 2D) = "white" {}
		_Floor("Floor", 2D) = "white" {}
		_Backwall("Back wall", 2D) = "white" {}
		_Sidewalls("Side walls", 2D) = "white" {}
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
			sampler2D _Sidewalls;
			sampler2D _MainTex;
			float4 _MainTex_ST;
			
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

				// Walls are either at 0 or 1; except for the back wall
				// which we always assume to occuply the z position of 1.
				float2 wallDistances = step(float2(0, 0), cameraToFragment);
				float3 wallPositions = float3(wallDistances.x, wallDistances.y, 1.0);

				float3 rayFractions = (wallPositions - i.cameraInObjectSpace) / cameraToFragment;

				float2 intersectionXY = (i.cameraInObjectSpace + rayFractions.z * cameraToFragment).xy;
				float2 intersectionXZ = (i.cameraInObjectSpace + rayFractions.y * cameraToFragment).xz;
				float2 intersectionZY = (i.cameraInObjectSpace + rayFractions.x * cameraToFragment).zy;

				fixed4 ceilingColor = tex2D(_Ceiling, intersectionXZ);
				fixed4 floorColor = tex2D(_Floor, intersectionXZ);

				// Is the camera looking up at the fragment? Then we hit the ceiling.
				// Otherwise, we hit the floor.
				fixed4 floorOrCeilingColor = lerp(floorColor, ceilingColor, step(0, cameraToFragment.y));

				fixed4 backWallColor = tex2D(_Backwall, intersectionXY);
				fixed4 sideWallColor = tex2D(_Sidewalls, intersectionZY);

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
