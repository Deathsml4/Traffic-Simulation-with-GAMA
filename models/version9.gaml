/**
* Name: version9
* Based on the internal skeleton template. 
* Author: Admin
* Tags: 
*/

model version9

global {
	/** Insert the global definitions, variables and actions here */
	car selected_car;
	int nb_cars_max;
	int nb_lanes_each_way <- 5;
	int nb_lanes <- (nb_lanes_each_way * 2) ;
	float lane_width <- 10.0;
	float world_height <- 100.0;
	float car_width_max <- 8.0;
	float car_height_max <- 10.0;
	float change_lane_step <- 0.8;
	float move_rescue_lane_step <- change_lane_step * 0.1;
	float car_spacing <- 5.0;
	float huge_spacing <- 10.0;
	float prob_damaged_car <- 0.01;
	float speed_default_top <- 1.6;
	float speed_default_min <- 0.7;
	float speed_diff_max <- 0.2; // độ lệch tốc độ max và tốc độ min với default
	int max_damaged_car_each_lane <- 1;
	int max_damaged_inrescue_duration <- 10;
	int max_damaged_inlane_duration <- 5;
	image_file car_left_icon <- image_file("../includes/car_left_2.png");
	image_file car_right_icon <- image_file("../includes/car_right_3.png");
	// road monitor
	float monitor_place <- world_height/2;
	float monitor_size <- 2#m;
	list<car> nearby_cars;
	list<car> damaged_cars;
	reflex monitor_on {
		nearby_cars <- car where (abs(each.location.x - monitor_place) < monitor_size);
		damaged_cars <- car where (each.damaged = true);
	}
	
	list<string> labels <- [];
	list<float> avg_num_cars_at_node <- [];  // Đây là list sẽ dùng cho chart: mỗi phần tử là TB của 10 cycle
    
    list<int> last_10_counts <- [];  // Buffer tạm
    
    int current_num_cars <- 0;  // Số xe hiện tại tại nút
    
    reflex update_num_cars {
        current_num_cars <- length(nearby_cars);  // Cách tính số xe tại nút
        if length(last_10_counts) = 10 {
            last_10_counts <- last(last_10_counts, 10);  // Giữ chỉ 10 cái mới nhất
            //last_10_counts <- [];
            labels << "[" + string(cycle-9) + "," + string(cycle) + "]";
        }
        write("Số xe tại monitor: " + current_num_cars);
        last_10_counts << current_num_cars;
    }
    
    reflex calculate_and_record_avg when:every (10 #cycles) {
            float avg <- mean(last_10_counts);
            write("TB = " + avg);
            avg_num_cars_at_node << avg;
    }
	
	bool dynamic_situation <- true;
	init {
		create my_monitor;
		float initial_y <- 0;
		create lane number: 1 { // Rescue Lane
			start_y <- initial_y;
			isRight <- false;
			initial_start_x <- 0;
			initial_y <- initial_y + lane_width;
			location <- {world_height / 2, start_y + lane_width /2};
			isRescueLane <- true;
		}
		create lane number: nb_lanes_each_way {
			start_y <- initial_y;
			isRight <- false;
			initial_start_x <- 0;
			initial_y <- initial_y + lane_width;
			location <- {world_height / 2, start_y + lane_width /2};
		}
//		create lane number: 3 {
//			start_y <- initial_y;
//			isRight <- true;
//			initial_y <- initial_y + lane_width;
//			location <- {(start_y + width) / 2, world_height / 2};
//		}
		create barrier {
			y <- initial_y;
		}
		create lane number: nb_lanes_each_way {
			start_y <- initial_y;
			isRight <- true;
			initial_start_x <- world_height;
			initial_y <- initial_y + lane_width;
			location <- {world_height / 2, start_y + lane_width / 2};
		}
		create lane number: 1 { //Rescue Lane
			start_y <- initial_y;
			isRight <- true;
			initial_start_x <- world_height;
			initial_y <- initial_y + lane_width;
			location <- {world_height / 2, start_y + lane_width / 2};
			isRescueLane <- true;
		}
		initial_y <- lane_width;
		create my_line number: nb_lanes + 1 {
			y <- initial_y;
			initial_y <- initial_y + lane_width;
		}
		create car_generator number: 1;
//		create car number: nb_cars {
//			is_right <- flip (0.5);
//			if (is_right ) {
//				
//			}
//		}
	}
}

species barrier {
	int y;
	aspect base3d {
		draw line([{0, y}, {world_height, y}]) depth: 2#m color: #darkblue;
	}
	
	aspect base2d {
		draw line([{0, y}, {world_height, y}]) color: #darkblue;
	}
}

species my_monitor {
	aspect base {
		draw buffer(line([{monitor_place, 0}, {monitor_place, (nb_lanes + 2) * lane_width}]), monitor_size) color: #red;
		draw triangle(3) at:{monitor_place, 0} rotate: 180 color: #red;
		draw string("Monitor here") at:{monitor_place - 7, -5} color: #black font: font("Arial", 12);
	}
}

species car_generator {
	reflex run_into_problem when: every(50#cycle) {
		lane target_lane <- one_of (lane where (each.isRescueLane = false));
		list<car> cars_in_lane <- car where (each.location.y = target_lane.start_y + lane_width/2);
		list<car> damaged_cars_in_lane <- cars_in_lane where (each.damaged = true);
		if (length(damaged_cars_in_lane) < max_damaged_car_each_lane) {
			if (rnd(1) < prob_damaged_car) {
				car target_car <- one_of (cars_in_lane);
				if (target_car = nil) {
					return;
				}
				ask target_car {
					damaged <- true;
					car_state_color <- #red;
					write ("car has prob at lane: " + round(location.y/10));
				}
			}
		}
	}
	reflex generate_car when: every(2#cycle) {
		int nb_new_car_left <- rnd(1);
		int nb_new_car_right <- rnd(1);
		if (nb_new_car_left != 0) {
			list<lane> left_lanes <- lane where (each.isRight = false and each.isRescueLane = false);
			list<lane> available <- left_lanes where (each.availableToAdd() = true);
			if (!empty(available)) {
				int car_x <- one_of(available).start_y + lane_width/2;
				create car number: nb_new_car_left {
					speed_top <- speed_default_top - speed_diff_max/2 + rnd(speed_diff_max);
					speed_min <- speed_default_min - speed_diff_max/2 + rnd(speed_diff_max);
					is_right <- false;
					location <- {world_height, car_x};
					my_icon <- car_left_icon;
					list <car> above_cars <- car where (each != self 
						and each.location.y = location.y 
						and each.location.x - location.x < 0);
					above_car <- first (above_cars sort_by (- each.location.x + location.x));
				}
			}
		}
		
		if (nb_new_car_right != 0) {
			list<lane> right_lanes <- lane where (each.isRight = true and each.isRescueLane = false);
			list<lane> available <- right_lanes where (each.availableToAdd() = true);
			if (!empty(available)) {
				int car_x <- one_of(available).start_y + lane_width/2;
				create car number: nb_new_car_left {
					speed_top <- speed_default_top - speed_diff_max/2 + rnd(speed_diff_max);
					speed_min <- speed_default_min - speed_diff_max/2 + rnd(speed_diff_max);
					is_right <- true;
					location <- {0, car_x};
					my_icon <- car_right_icon;
					list <car> above_cars <- car where (each != self 
						and each.location.y = location.y 
						and each.location.x - location.x > 0);
					above_car <- first (above_cars sort_by (each.location.x - location.x));
				}
			}
		}
	}
}

species car_counter {
	int x;
	int size;
	reflex count_car when: every (2#cycle) {
		list<car> nearby_cars <- car where (abs(each.location.x - x) < size);
		int nb_cars <- length(nearby_cars);
	}
}

species lane {
	float start_y;
	float width <- lane_width;
	bool isRight;
	int initial_start_x;
	bool isRescueLane <- false;
	bool availableToAdd {
		float start_x;
		list<car> car_in_lane <- car where (each.location.y = start_y + width/2);
		list<car> blocking <- [];
		if (isRight) {
			start_x <- 0.0;
			//blocking <- car_in_lane where (each.location.x - car_spacing < start_x + car_height_max);
			blocking <- car_in_lane where (each.location.x - start_x < car_height_max + car_spacing);
		} else {
			start_x <- world_height;
			blocking <- car_in_lane where (each.location.x + car_spacing > start_x - car_height_max);
		}
		return empty(blocking);
	}
	
	bool freeAt(float x, float width) {
		list<car> car_in_lane <- car where (each.location.y = start_y + width/2);
		float bot_x;
		float top_x;
		if (isRight) {
			bot_x <- x - car_height_max/2 - car_spacing;
			top_x <- x + car_height_max/2 + car_spacing;	
		} else {
			top_x <- x + car_height_max/2 + car_spacing;
			bot_x <- x - car_height_max/2 - car_spacing;
		}
		list<car> blocking <- car_in_lane where (each.location.x > bot_x and each.location.x < top_x);
		return empty(blocking);
	}
	
	bool hugeSpaceAt(float x, float width) {
		list<car> car_in_lane <- car where (each.location.y = start_y + width/2);
		float bot_x;
		float top_x;
		if (isRight) {
			bot_x <- x - car_height_max/2 - car_spacing;
			top_x <- x + car_height_max/2 + car_spacing + huge_spacing;	
		} else {
			top_x <- x + car_height_max/2 + car_spacing;
			bot_x <- x - car_height_max/2 - car_spacing - huge_spacing;
		}
		list<car> blocking <- car_in_lane where (each.location.x > bot_x and each.location.x < top_x);
		return empty(blocking);
	}
	
	bool hugeSpaceBehind(float x, float width) {
		list<car> car_in_lane <- car where (each.location.y = start_y + width/2);
		float bot_x;
		float top_x;
		if (isRight) {
			bot_x <- x - car_height_max/2 - car_spacing - huge_spacing;
			top_x <- x + car_height_max/2 + car_spacing;	
		} else {
			top_x <- x + car_height_max/2 + car_spacing + huge_spacing;
			bot_x <- x - car_height_max/2 - car_spacing;
		}
		list<car> blocking <- car_in_lane where (each.location.x > bot_x and each.location.x < top_x);
		return empty(blocking);
	}
	
	lane myRightLane {
		lane right_lane <- one_of (lane where (start_y = each.start_y + width/2));
		return right_lane;
	}
	
	lane myLeftLane {
		lane left_lane <- one_of (lane where (start_y = each.start_y - width/2));
		return left_lane;
	}
	
	aspect base {
		if (isRescueLane) {
			draw rectangle(world_height, width) at: {location.x, location.y, -3} color: #white; 
		} else {
			draw rectangle(world_height, width) at: {location.x, location.y, -3} color: #gray; 
			if (isRight) {
				draw circle(0.5) color: #red at: {0, start_y + width / 2};	
			} else {
				draw circle(0.5) color: #red at: {world_height, start_y + width / 2};	
			}
		}
	}
}

species my_line {
	float y;
	aspect base {
		draw line([{0, y}, {world_height, y}]) color: #black;
	}
}

species car {
	float width <- 6.0;
	float height <- 8.0;
	float default_speed <- 1.0;
	float speed <- default_speed;
	float speed_ratio <- 1.3;
	float speed_top;
	float speed_min;
	int damaged_inrescue_duration <- 0;
	int damaged_inlane_duration <- 0;
	bool damaged <- false;
	bool is_right;
	image_file my_icon;
	rgb car_state_color <- #yellow;
	car above_car;
	bool isChangingLane <- false;
	
	
	string getLocation {
		return (" " + round(location.x) + ":" + location.y);
	}
	
	reflex find_car_ahead {
		list <car> left_cars <- car where (each != self 
									and each.location.y = location.y 
									and each.location.x - location.x < 0);
		car left_car <- first (left_cars sort_by (- each.location.x + location.x));
		list <car> right_cars <- car where (each != self 
									and each.location.y = location.y 
									and each.location.x - location.x > 0);
		car right_car <- first (right_cars sort_by (each.location.x - location.x));
		if (is_right) {
			above_car <- right_car;
		} else {
			above_car <- left_car;
		}
	}
	
	reflex move when: every(2#cycle) {
		if (damaged) {
			do handle_damaged_car;
			return;
		}
		if (location.x > world_height + 1 or location.x < -1) {
			list <car> left_cars <- car where (each != self 
									and each.location.y = location.y 
									and each.location.x - location.x < 0);
					car left_car <- first (left_cars sort_by (- each.location.x + location.x));
					list <car> right_cars <- car where (each != self 
									and each.location.y = location.y 
									and each.location.x - location.x > 0);
					car right_car <- first (right_cars sort_by (each.location.x - location.x));
					if (is_right) {
						if (left_car = nil) {
							return;
						}
						ask (left_car) {
							above_car <- nil;
						}
					} else {
						if (right_car = nil) {
							return;
						}
						ask (right_car) {
							above_car <- nil;
						}
					}
			do die;
		}
		if (isChangingLane) {
			isChangingLane <- false;
		}
		if (above_car = nil) {
			do accelerate;
			do move_forward;
			return;
		}
		float min_dist <- above_car distance_to(self);
		if (min_dist > car_spacing + car_height_max + huge_spacing) {
			do accelerate;
		} else {
			do try_change_lane;
			if (min_dist < car_spacing + car_height_max) {
				speed <- 0.0;
				//do try_change_lane;
			} else {
				do decelerate;
				
			}
		}
		do move_forward;
	}
//	reflex got_problem when: every(50#cycle) {
//		if (rnd(1) < prob_damaged_car) {
//			list<car> damaged_cars_in_lane <- car where(each != self
//				and each.location.y = location.y
//				and damaged = true
//			);
//			if (length(damaged_cars_in_lane) < max_damaged_car_each_lane) {
//				damaged <- true;
//				car_color <- #red;
//			}
//		}
//	}
	action handle_damaged_car {
		speed <- move_rescue_lane_step;
		if (dynamic_situation) {
			lane my_lane <- one_of (lane where (each.start_y = location.y - lane_width/2));
			damaged_inlane_duration <- damaged_inlane_duration + 1;
			if (damaged_inlane_duration < max_damaged_inlane_duration) {
				return;
			}
			if (my_lane = nil) {
				write ("not found my lane at " + (location.y - lane_width/2));
			}
			if (my_lane.isRescueLane) {
				if (damaged_inlane_duration > 0) {
					damaged_inlane_duration <- 0;
				}
				damaged_inrescue_duration <- damaged_inrescue_duration + 1;
				if (damaged_inrescue_duration >= max_damaged_inrescue_duration) {
					do recover;
				}
				return;
			}
			if (damaged_inlane_duration >= max_damaged_inlane_duration + max_damaged_inrescue_duration) {
				do recover;
				return;
			}
			if (is_right) {
				lane right_lane <- one_of (lane where (each.start_y = location.y + lane_width/2));
				if (right_lane = nil) {
					write("not found the lane at " + location.y + lane_width/2);
					return;
				}
				ask right_lane {
					if(hugeSpaceBehind(location.x, lane_width)) {
						float new_y <- start_y;
						ask myself {
							do move_to_new_lane(new_y);
						}
					}
				}
//				if (right_lane = nil) {
//					return;
//				}
//				ask right_lane {
//					if(freeAt(location.x, lane_width)) {
//						float new_y <- start_y;
//						ask myself {
//							do move_to_new_lane(new_y);
//						}
//					}
//				}
			} else {
				lane left_lane <- one_of (lane where (each.start_y = location.y - 3 * lane_width/2));
				if (left_lane = nil) {
					write("not found the lane at " + location.y + lane_width/2);
					return;
				}
				if (left_lane = nil) {
					return;
				}
				ask left_lane {
					if(hugeSpaceBehind(location.x, lane_width)) {
						float new_y <- start_y;
						ask myself {
							do move_to_new_lane(new_y);
						}
					}
				}
			}
		}
	}
	action recover {
		lane my_lane <- one_of (lane where (each.start_y = location.y - lane_width/2));
		if (my_lane.isRescueLane = false) {
			damaged <- false;
			speed <- speed_min;
			car_state_color <- #yellow;
			return;
		}
		car_state_color <- #yellow;
		if (!is_right) {
				lane right_lane <- one_of (lane where (each.start_y = location.y + lane_width/2));
				if (right_lane = nil) {
					write("not found the lane at " + location.y + lane_width/2);
					return;
				}
				ask right_lane {
					if(freeAt(location.x, lane_width)) {
						float new_y <- start_y;
						ask myself {
							do move_to_new_lane(new_y);
						}
					}
				}
//				if (right_lane = nil) {
//					return;
//				}
//				ask right_lane {
//					if(freeAt(location.x, lane_width)) {
//						float new_y <- start_y;
//						ask myself {
//							do move_to_new_lane(new_y);
//						}
//					}
//				}
			} else {
				lane left_lane <- one_of (lane where (each.start_y = location.y - 3 * lane_width/2));
				if (left_lane = nil) {
					write("not found the lane at " + location.y + lane_width/2);
					return;
				}
				if (left_lane = nil) {
					return;
				}
				ask left_lane {
					if(freeAt(location.x, lane_width)) {
						float new_y <- start_y;
						ask myself {
							do move_to_new_lane(new_y);
						}
					}
				}
			}
		my_lane <- one_of (lane where (each.start_y = location.y - lane_width/2));
		if (my_lane.isRescueLane = false) {
			damaged <- false;
			speed <- speed_min;
		}
	}
	action move_forward_greedy {
		if (speed > 0) {
			
		} else {
			do handle_damaged_car;
		}
	}
	action accelerate {
		//if damaged { speed <- 0.0; return; }
		if (speed = 0) {
			speed <- speed_min;
		}
		speed <- min(speed_top, speed * speed_ratio);
		car_state_color <- #green;
	}
	action decelerate {
		//if damaged { speed <- 0.0; return; }
		speed <- max(speed_min, speed / speed_ratio);
		car_state_color <- #violet;
	}
	action stay_same {
		if damaged { speed <- 0.0; return; }
		car_state_color <- #yellow;
	}
	action move_forward {
		if damaged {
			speed <- 0.0; return;
		}
		if (is_right) {
			location <- {location.x + speed, location.y};
		} else {
			location <- {location.x - speed, location.y};
		}
	}
	action try_change_lane{
		if damaged {
			speed <- 0.0;
			return;
		}
		float current_x <- location.x;
		list<lane> target_lane <- lane where(each.start_y != location.y - width/2 
			and abs(location.y - width/2 - each.start_y) <= 10 // neighbor lane
//			and freeAt(current_x, width)
			and each.isRight = is_right
			and each.isRescueLane = false
		);
		bool change_flag <- false;
		ask target_lane {
			list<car> car_in_lane <- car where (each.location.y = start_y + width/2);
			if (hugeSpaceAt(myself.location.x, width)) {
				float new_y <- start_y;
				change_flag <- true;
				ask myself {
					//do prepare_to_move;
					do move_to_new_lane(new_y);
				}
			}
		}
	}
	
	action prepare_to_move {
		list <car> left_cars <- car where (each != self 
									and each.location.y = location.y 
									and each.location.x - location.x < 0);
					car left_car <- first (left_cars sort_by (- each.location.x + location.x));
					list <car> right_cars <- car where (each != self 
									and each.location.y = location.y 
									and each.location.x - location.x > 0);
					car right_car <- first (right_cars sort_by (each.location.x - location.x));
					if (is_right) {
						if (left_car = nil) {
							return;
						}
						ask (left_car) {
							self.above_car <- myself.above_car;
							if (self.above_car != nil) {
								write ("asign car " + round(self.above_car.location.x) + ":" + self.above_car.location.y);
							} else {
								write ("no car ahead");
							}
							write ("to car " + round(left_car.location.x) + ":" + left_car.location.y);
						}
					} else {
						if (right_car = nil) {
							return;
						}
						ask (right_car) {
							self.above_car <- myself.above_car;
							if (self.above_car != nil) {
								write ("asign car " + round(self.above_car.location.x) + ":" + self.above_car.location.y);
								//write ("asign car " + above_car.getLocation());
							} else {
								write ("no car ahead");
							}
							write ("to car " + round(right_car.location.x) + ":" + right_car.location.y);
						}
					}
	}
	
	action move_to_new_lane (float y) {
		isChangingLane <- true;
		list<car> car_in_lane <- car where (each.location.y = y + width/2);
		list <car> left_cars <- car where (each != self 
						and each.location.y = y + width/2
						and each.location.x - location.x < 0);
		car left_car <- first (left_cars sort_by (- each.location.x + location.x));
		list <car> right_cars <- car where (each != self 
						and each.location.y = y + width/2
						and each.location.x - location.x > 0);
		car right_car <- first (right_cars sort_by (each.location.x - location.x));
		if (is_right) {
//			above_car <- right_car;
//			if (left_car != nil) {
//				ask left_car {
//					above_car <- myself;
//				}
//			}
			location <- {location.x + 0.3, y + lane_width/2};
		} else {
//			above_car <- left_car;
//			if (right_car != nil) {
//				ask right_car {
//					above_car <- myself;
//				}
//			}
			location <- {location.x - 0.3, y + lane_width/2};
		}
		//write (y + lane_width/2);
	}
	
//	action move_to_target_lane {
//	
//		// --- 1. Lái (Steer) ---
//		// Đặt heading (hướng đi) chéo 
//		if (is_left_direction) { // Đang đi 90 độ
//			if (target_lane_y < location.y) { // Chuyển "xuống" (về phía Y âm)
//				set heading <- 135.0; // Xuống-phải
//			} else { // Chuyển "lên" (về phía Y dương)
//				set heading <- 45.0; // Lên-phải
//			}
//		} else { // Đang đi 270 độ
//			if (target_lane_y < location.y) { // Chuyển "xuống"
//				set heading <- 225.0; // Xuống-trái
//			} else { // Chuyển "lên"
//				set heading <- 315.0; // Lên-trái
//			}
//		}
//	
//		// --- 2. Kiểm tra an toàn ---
//		// Tính khoảng cách kiểm tra 
//		float check_distance <- observation_distance + abs(location.y - target_lane_y);
//		
//		// Tạo hình nón quan sát THEO HƯỚNG CHÉO MỚI 
//		geometry observation_cone <- (
//			cone(int(check_distance), int(observation_angle)) 
//			rotated_by self.heading // Dùng heading chéo (45, 135...)
//		) at self.location;
//		
//		list<agent> blocking_cars <- car overlapping observation_cone without self;
//	
//		// --- 3 & 4. Hành động ---
//		if (length(blocking_cars) = 0) {
//			// Làn trống: Di chuyển chéo 
//			do move speed: change_lane_step;
//			
//			// Sửa lỗi floating point (tương đương 'precision ycor 1') 
//			set location.y <- round(location.y * 10.0) / 10.0;
//			
//		} else {
//			// Làn bị cản: Tìm xe gần nhất
//			agent nearest_car <- first(blocking_cars sort_by (each.location distance self.location));
//			
//			// Logic tăng/giảm tốc 
//			// 'location towards ...' trong GAMA trả về góc tuyệt đối (0-360)
//			float angle_to_blocker <- self.location towards nearest_car.location;
//			
//			// Logic của NetLogo: 
//			// < 180 (phía Đông/phải) vs > 180 (phía Tây/trái)
//			if (angle_to_blocker < 180.0) {
//				do slow_down;
//			} else {
//				do speed_up;
//			}
//		}
//	
//		// --- 5. Đặt lại (Reset) ---
//		// Đặt lại heading đi thẳng ngay lập tức 
//		if (is_left_direction) {
//			set heading <- 90.0;
//		} else {
//			set heading <- 270.0;
//		}
//		
//		// Tùy chọn: Đặt lại màu (như trong NetLogo) 
//		// set color <- ... 
//	}
	aspect base {
		draw rectangle (height, width) color: car_state_color border:#black;
	}
	aspect icon {
		draw my_icon size: {height, width};
		draw line([above_car, self]) color: #yellow;
	}
	aspect geom3d {
		rgb car_color <- #green;
		if (is_right) {
			car_color <- #blue;
		}
		draw obj_file("../includes/Low_Poly_Vehicles_car02.obj") size: {height * 3, width * 3, 3.0 * 3} rotate: 90::{-1, 1, 1} texture: "../includes/car02.png" color: car_color;
	}
}

experiment version9 type: gui {
	/** Insert here the definition of the input and output of the model */
	parameter "Vị trí đặt monitor" var: monitor_place min: 0.0 max: world_height;
	parameter "Độ rộng giám sát" var: monitor_size min: 1.0 max: 5.0;
	output {
		monitor "Tổng số xe: " value: length(car);
		monitor "Số xe bị hỏng: " value: length(damaged_cars);
		
		display road_display type:3d {
			species lane aspect:base;
			species my_line aspect: base;
			species car aspect: geom3d;
			species barrier aspect: base3d;
			species my_monitor aspect: base;
			
		}
		display no_icon type: 2d {
			species lane aspect:base;
			species my_line aspect: base;
			species car aspect: base;
			species barrier aspect: base2d;
			species my_monitor aspect: base;
		}
		display Car_Population type:2d refresh: every(2#cycle) {
			chart "Số lượng xe theo thời gian" type: scatter {
            data "Số lượng xe tại monitor" value: length(nearby_cars) line_visible:false;
         }
		} 
		display Car_Avg type:2d refresh: every(1#cycles){
            chart "Số xe trung bình tại nút giao (mỗi 10 cycle)"
                  type: series
                  style: bar
                  x_label: "Khoảng thời điểm"
                  y_label: "Số xe trung bình"
                  size: {1, 0.5} position: {0, 0.5}
                   {
                data "TB số xe" value: avg_num_cars_at_node color: #green marker_size: 0;
            }
        }
//        display Car_Avg type:2d {
//        	chart "Số lượng xe TB tại monitor mỗi 10 cycle"
//              type: histogram
//              x_label: "Khoảng thời điểm"
//              y_label: "Trung bình số xe (mỗi 10 cycle)"
//              size: {1, 0.4} position: {0, 0.05} {
//            data string(cycle)
//            value: avg_num_cars_at_node  color: #teal;
//	        }
//	    }
	}
}
