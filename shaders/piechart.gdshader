shader_type canvas_item;

uniform int sector_mask;

float smootherstep(float edge, float mask, float offset) {
	return smoothstep(edge, edge + offset, mask);
}

void fragment() {
	int sectors = 12;
	float sectorsF = float(sectors);
	float sectorSize = (PI * 2.0) / sectorsF;

	vec2 cuv = UV * 2. - 1.;
	// 1. Keep angle normalized to radians or a clean range
	float angle = atan(-cuv.x, cuv.y);
	angle += PI / sectorsF;
	if (angle > PI) angle -= PI * 2.0;
	if (angle < -PI) angle += PI * 2.0;
	
	float circleSDF = distance(cuv, vec2(0.0));
	float color = 0.0;
	float thickness = 0.016 / max(circleSDF, 0.01); 
	float sectorIndex = floor((angle + PI) / sectorSize);
	float sectorStart = -PI + (sectorIndex * sectorSize);
	color = smootherstep(sectorStart + thickness, angle, 0.015);
	// Mask out the next line edge to isolate the sector
	float nextSectorStart = sectorStart + sectorSize;
	color *= smootherstep(angle, nextSectorStart - thickness, 0.015);
	
	float normAngle = angle + PI; 
	int sliceIndex = int(floor(normAngle / sectorSize)) % int(sectors);

	int ringIndex = -1;
	if (circleSDF >= 0.65 && circleSDF <= 0.99) {
	    ringIndex = 0;
	} else if (circleSDF >= 0.30 && circleSDF <= 0.64) {
	    ringIndex = 1;
	}

	int sectorID = -1;
	if (ringIndex != -1) {
	    sectorID = (ringIndex * sectors) + sliceIndex; 
	}
	
	float sectorIsActive = 0.0;

	if (sectorID != -1) {
	    // Create a bit filter for the current sector ID
	    int bitFilter = 1 << sectorID; 
	    
	    // Check if the bit is set in our mask
	    if ((sector_mask & bitFilter) != 0) {
	        sectorIsActive = 1.0;
	    }
	}
	
	color *= smootherstep(circleSDF, 0.99, 0.013);
	float ring1 = color;
	ring1 -= smootherstep(circleSDF, 0.667, 0.013);
	ring1 = max(ring1, 0.);
	float ring2 = color;
	ring2 *= smootherstep(circleSDF, 0.667 - thickness * 1.667, 0.012);
	ring2 -= smootherstep(circleSDF, 0.333, 0.01);
	ring2 = max(ring2, 0.);
	float center = smootherstep(circleSDF, 0.29, 0.01);
	float ringsMask = max(max(ring1, ring2), center);

	COLOR = vec4(vec3(1.), ringsMask * 0.1 + sectorIsActive * ringsMask * 0.3);
	//COLOR = vec4(vec3(sec + sec2), 1);
}
