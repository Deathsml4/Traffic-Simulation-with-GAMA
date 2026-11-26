/**
* Name: version8
* Based on the internal empty template. 
* Author: Admin
* Tags: 
*/


model expressways_simplified

global {
	// Parameters (tune as needed)
	int current_id <- 0;
	int number_of_lanes_way <- 3; // lanes per direction
	float lane_width <- 3.5;      // meters (visual only)
	int world_length <- 800;       // X extent (meters)
	bool dynamic_situation <- true;
	int number_of_cars <- 80;

	float speed_max <- 1.0;       // ~ 120 km/h in m/s
	float speed_min <- 0.0;
	float speed_ratio <- 0.35;     // acceleration coefficient
	float collision_distance <- 2.0;

	float prob_add_car <- 0.005;
	float prob_remove_car <- 0.00005;

	float change_lane_step <- 0.8;   // lateral step per tick (m)
	float observation_distance <- 25; // look-ahead distance (m)

	// Derived
	int number_of_lanes <- number_of_lanes_way * 2 + 2; // add 2 central buffers
	list<float> lane_y;

	int nb_collisions <- 0;

	// Road geometry: origin at bottom-left, lanes laid along X
	file shp_file; // not used, reserved for future road networks

	init {
		create object number: 1 {
			location <- {0, 0};
		}
		float total_height <- number_of_lanes * lane_width;
		// Build lane centerlines (bottom to top)
		lane_y <- [];
		loop i from: 0 to: (number_of_lanes - 1) {
			lane_y <- lane_y + (i * lane_width + lane_width / 2.0);
		}
		//lane_y <- (0 ..< number_of_lanes) collect (each * lane_width + lane_width / 2.0);
		create car number: number_of_cars {
			location <- {rnd(world_length), one_of(lane_y)};
			lane_index <- index_of(lane_y, location.y);
			speed_top <- speed_min + rnd(speed_max - speed_min);
			speed <- min(speed_top, speed_min + rnd(8.0));
			color <- #gray;
		}
	}
//	reflex car_spawner when: dynamic_situation {
//		if rnd(1.0) <= prob_add_car and length(cars) < 20000 {
//			create cars number: 1 {
//				lane_index <- rnd(length(lane_y));
//				loc <- {0.0, lane_y at lane_index};
//				speed_top <- speed_min + rnd(speed_max - speed_min);
//				speed <- min(speed_top, speed_min + rnd(8.0));
//				color <- #gray;
//			}
//		}
//	}
//	reflex car_remover when: dynamic_situation {
//		if (not empty(cars)) and (rnd(1.0) <= prob_remove_car) {
//			ask one_of cars { die; }
//		}
//	}
}

species car {
	// Kinematics
	float speed <- 1.0;         // m/tick
	float speed_top <- 25.0;    // m/tick
	int lane_index <- 0;        // current lane index in global.lane_y
	int target_lane <- -1;      // -1 means stay
	float length <- 4.5;        // meters (for spacing)
	float width <- 1.8;
	int id;

	bool damaged <- false;      // simplified: unused in this version
	rgb base_color <- #steelblue;

	action accelerate {
		if damaged { speed <- 0.0; return; }
		speed <- min(speed_top, speed + speed_ratio);
	}
	action decelerate {
		speed <- max(speed_min, speed - speed_ratio);
	}
	reflex keep_in_bounds {
		// wrap-around in X to emulate long highway
		float new_x;
		if location.x > world_length { new_x <- 0.0; }
		if location.x < 0 { new_x <- float(world_length); }
		location <- {new_x, location.y};
	}
	
	// Tính khoảng cách dọc theo trục X đến xe khác, có tính wrap-around
	float forward_distance_to(car other) {
		float dx <- other.location.x - location.x;
		if dx < 0 { dx <- world_length + dx; } // nếu ở phía sau, cộng thêm chu kỳ
		return dx;
	}
	
	// Chọn xe phía trước gần nhất trong danh sách candidates
	car get_car_ahead(list<car> candidates) {
		car best <- nil;
		float best_dx <- 1e12;
		ask candidates {
			float d <- forward_distance_to(self);
			if d < best_dx {
				best_dx <- d;
				best <- self;
			}
		}
		return best;
	}

	// Find car ahead in same lane within observation window
	reflex perceive_and_adjust {
		nb_collisions <- nb_collisions; // read global (no-op to make intent explicit)
		float y_lane <- lane_y at lane_index;
		// candidates in same lane and ahead (positive delta x, modulo world length)
		list<car> same_lane <- car where (each != self and abs(each.location.y - y_lane) < (lane_width * 0.3));
		if empty(same_lane) {  do accelerate; return; }

		// get ahead by considering wrap-around
		car ahead <- get_car_ahead(same_lane);

		float dx_ahead <- (ahead.location.x >= location.x)
			? (ahead.location.x - location.x)
			: (world_length - location.x + ahead.location.x);

		// collision check (very simple hit-box using distance in 2D)
		if (self distance_to(ahead) < collision_distance) {
			nb_collisions <- nb_collisions + 1;
			do decelerate;
			return;
		}

		// car-following: target gap ~ 1.3 * length + speed headway
		float desired_gap <- (1.3 * length) + (0.6 * speed);
		if dx_ahead < desired_gap {
			do decelerate;
		} else {
			do accelerate;
		}
	}

	// Attempt lane change if blocked and adjacent lane is freer
	action try_lane_change {
		if damaged { return; }
		float y_now <- lane_y at lane_index;
		bool blocked <- false;

		// Simple blockage test: any car within short headway directly ahead
		list<car> same_lane_ahead <- car where (each != self and abs(each.location.y - y_now) < (lane_width * 0.3)
			and ((each.location.x >= location.x and (each.location.x - location.x) < observation_distance)
			  or (each.location.x < location.x and (world_length - location.x + each.location.x) < observation_distance)));
		blocked <- (length(same_lane_ahead) > 0);

		if not blocked { return; }

		list<int> candidates <- [];
		if lane_index > 0 { candidates <- candidates + (lane_index - 1); }
		if lane_index < (length(lane_y) - 1) { candidates <- candidates + (lane_index + 1); }
		if empty(candidates) { return; }

		// Choose side with fewer neighbors in a safety window
		int best_lane <- lane_index;
		int best_count <- 999999;
		int num <- length(candidates);
		
		loop i from: 0 to: num {
			float y_target <- lane_y [i];
			int cnt <- length(car where (each != self and abs(each.location.y - y_target) < lane_width * 0.5));
			if cnt < best_count {
				best_count <- cnt;
				best_lane <- i; 
			}
		}
		if best_lane != lane_index {
			target_lane <- best_lane;
		}
//		ask (candidates) {
//			float y_target <- lane_y at each;
//			int cnt <- length(car where (each != self
//				and abs(each.location.y - y_target) < (lane_width * 0.5)
//				and distance(each, {location.x + 0.0, y_target}) < observation_distance));
//			if cnt < best_count {
//				best_count <- cnt; best_lane <- li;
//			}
//		}
//
//		if best_lane != lane_index {
//			target_lane <- best_lane;
//		}
	}

	reflex perform_lane_change when: target_lane >= 0 and target_lane < length(lane_y) {
		float y_target <- lane_y[target_lane];
		// move laterally towards target lane
		//float dir <- sign(y_target - location.y);
		float dy <- y_target - location.y;
		float eps <- 1e-6;
		float dir <- (abs(dy) <= eps) ? 0.0 : ((dy > 0.0) ? 1.0 : -1.0);
		location <- {location.x, location.y + dir * min(change_lane_step, abs(y_target - location.y))};
		// snap if close enough
		if abs(location.y - y_target) < (0.1) {
			location <- {location.x, y_target};
			//location.y <- y_target;
			lane_index <- target_lane;
			target_lane <- -1;
		}
	}

	reflex move_forward when: every (1#minute) {
		if damaged { return; }
		do accelerate; // after any possible deceleration above, try to regain speed
		location <- {location.x + speed, location.y};
	}

	aspect base {
		draw rectangle(width, length) color: (damaged ? #red : base_color) rotate: 90 at: location;
	}
}

// Visualization of lanes
species lane {
	float y;
	aspect base {
		draw line({0, y}, {world_length, y}) color: #lightgray;
	}
}

species object {
	float x;
	float y;
	aspect base {
		draw circle(1) color: #red;
	}
}

experiment gui type: gui {
	parameter "Number of Cars: " var: number_of_cars min: 0 max: 1000;
	
	output {
		display map refresh: every(1#hour) background: #white {
//			// road background
//			draw rectangle(world_length, number_of_lanes * lane_width) color: rgb(240,240,240) at: {world_length / 2.0, (number_of_lanes * lane_width) / 2.0};
//			// lane centerlines
//			ask (lane_y) {
//				draw line({0, each}, {world_length, each}) color: #silver;
//			}
			species car aspect: base;
			species lane aspect: base;
			species object aspect: base;
			
		}
		monitor "Cars" value: length(car);
		monitor "Collisions (tick)" value: nb_collisions;
//		display my_char {
//			chart "Cars over time" type: series {
//				data "cars" value: length(car);
//			}
//		}
	}
}
