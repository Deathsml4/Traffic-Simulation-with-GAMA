/**
* Name: version7
* Based on the internal empty template. 
* Author: Admin
* Tags: 
*/


/**
 * Model: TrafficExpressway
 * Author: (Dựa trên mô hình NetLogo "Expressways.nlogo")
 * Description: Mô phỏng giao thông hai chiều đơn giản hóa, tập trung vào logic
 * tăng/giảm tốc, xử lý xe phía trước và chuyển làn khi mất kiên nhẫn.
 * Mô hình này KHÔNG bao gồm các thuật toán Học tăng cường (RL) phức tạp
 * có trong tệp .nlogo gốc.
 */
model TrafficExpressway

global {
	// --- Thông số thế giới và đường
	int number_of_lanes_way <- 5; //
	float lane_width <- 3.5; // [cite: 1]
	geometry road_shape;
	list<float> car_lanes_left;
	list<float> car_lanes_right;
	
	// --- Thông số mô phỏng
	int number_of_cars <- 100; // [cite: 243]
	float acceleration <- 0.005; //
	float deceleration <- 0.02; //
	float speed_max <- 1.0; // [cite: 37]
	float speed_min <- 0.0;
	int max_patience <- 50; //
	float speed_ratio <- 0.35; // [cite: 38]
	
	// --- Thông số quan sát của xe
	float observation_distance <- 5.0; // Giá trị điều chỉnh từ 2.5 gốc [cite: 24]
	float observation_angle <- 60.0; // [cite: 25]
	float change_lane_step <- 0.08; // 
	
	// --- Khởi tạo thế giới (Tương đương `setup` và `draw-road`)
	init {
		// Tính toán tọa độ Y của các làn
		car_lanes_left <- [];
		car_lanes_right <- [];
		loop n from: 0 to: number_of_lanes_way - 1 {
			car_lanes_left <- car_lanes_left + (2 * (n - number_of_lanes_way) * (lane_width / 2.0)); // [cite: 7, 195]
			car_lanes_right <- car_lanes_right + (2 * (number_of_lanes_way - n) * (lane_width / 2.0)); // [cite: 8, 195]
		}
		
		// Tính toán hình dạng con đường
		float total_road_height <- (number_of_lanes_way * 2 + 3) * lane_width; // [cite: 5, 27]
		road_shape <- envelope({0, -total_road_height / 2}, {world_width, total_road_height / 2});

		// Tạo các xe
		create car number: number_of_cars; // 
	}
}

// --- Loài Xe (Tác tử) ---
species car skills: [moving] {
	// --- Thuộc tính của xe
	float speed; // [cite: 28]
	float speed_top; // [cite: 29]
	float target_lane_y; // Tọa độ y của làn mong muốn 
	int patience; // [cite: 31]
	bool is_left_direction; // Đánh dấu xe đi chiều bên trái (heading 90)

	// --- Khởi tạo xe
	init {
		// Chọn chiều ngẫu nhiên và làn tương ứng
		is_left_direction <- flip(0.5);
		float y_pos;
		if (is_left_direction) {
			y_pos <- one_of(car_lanes_left);
			//heading <- 90.0; // Tương đương heading 90 trong NetLogo
		} else {
			y_pos <- one_of(car_lanes_right);
			//heading <- 270.0; // Tương đương heading 270 trong NetLogo
		}
		
		// Đặt vị trí, tốc độ, kiên nhẫn
		location <- {rnd(world_width), y_pos};
		target_lane_y <- y_pos;
		speed <- 0.75 + rnd(speed_max - 0.75); // [cite: 191]
		speed_top <- speed_max;
		patience <- (max_patience / 2) + rnd(max_patience / 2); // 
	}
	
	// Đặt hình dạng và màu sắc
	aspect default {
		draw circle(2.0) size: 2.0 color: is_left_direction ? #skyblue : #lightgreen; // 
	}

	// --- Phản xạ: Hành vi chính của xe mỗi bước
	reflex move {
		// 1. Luôn cố gắng tăng tốc
		do speed_up; // 
		
		// 2. Xử lý xe cản phía trước
		do handle_blocking_cars; // 
		
		// 3. Di chuyển
		do move speed: (speed * speed_ratio); // 
		
		// 4. Xử lý hết kiên nhẫn
		if (patience <= 0) { // 
			do choose_new_lane;
		}
		
		// 5. Di chuyển về làn mục tiêu nếu đang không ở đúng làn
		if (location.y != target_lane_y) { // 
			do move_to_target_lane;
		}
	}

	// --- Hành động: Tăng tốc
	action speed_up { // 
		speed <- speed + acceleration;
		if (speed > speed_top) {
			speed <- speed_top;
		}
	}

	// --- Hành động: Giảm tốc
	action slow_down { // 
		if (speed > deceleration) {
			speed <- speed - deceleration;
			if (speed < speed_min) {
				speed <- speed_min;
			}
			patience <- patience - 1; // 
			if (patience < 0) {
				patience <- 0;
			}
		}
	}

	// --- Hành động: Xử lý xe cản
	action handle_blocking_cars {
    
	    // BƯỚC 1: Tạo ra một geometry hình nón phía trước xe
	    // Nó lấy 3 tham số: 
	    //   - Bán kính: observation_distance
	    //   - Góc mở: observation_angle
	    //   - Vị trí: at location (tại vị trí của xe)
	    //   - Hướng: heading heading (hướng của xe)
	    float angle <- (is_left_direction ? 90.0:270.0);
	    geometry observation_cone <- 
		    cone(int(observation_distance), int(observation_angle))
		    rotated_by angle;
//	    geometry observation_cone <- (
//	        cone(int(observation_distance), int(observation_angle)) 
//	        rotated_by self.heading
//	    ) at location;
//	    geometry observation_cone <- (
//	        cone(int(observation_distance), int(observation_angle)) 
//	        rotated_by heading
//	    ) at location;
//	    geometry observation_cone <- cone(observation_distance, observation_angle) at location heading heading;
	
	    // BƯỚC 2: Tìm TẤT CẢ các xe (loài car)
	    // chồng lấn (overlapping) với hình nón đó,
	    // và loại trừ chính bản thân mình (without self)
	    list<car> blocking_cars <- car overlapping observation_cone;
	    
	    // Phần logic bên dưới giữ nguyên
	    
	    if (length(blocking_cars) > 0) {
	        // Sắp xếp để tìm xe gần nhất
	        car nearest_car <- first(blocking_cars sort_by (each distance_to(self)));
	        
	        if (nearest_car != nil) {
	            // Nếu xe phía trước đang chạy
	            if (nearest_car.speed > 0) {
	                speed <- nearest_car.speed;
	                do slow_down;
	            } 
	            // Nếu xe phía trước đứng yên (xe hỏng)
	            else {
	                loop while: (speed > 0.05) {
	                    do slow_down;
	                }
	                if (location.y = target_lane_y) {
	                    do choose_new_lane;
	                }
	            }
	        }
	    }
	}
	
//	action handle_blocking_cars { // 
//		// Tìm các xe trong "hình nón" quan sát
//		list<agent> blocking_cars <- self neighbors_in observation_distance angle: observation_angle;
//		
//		if (length(blocking_cars) > 0) {
//			// Sắp xếp để tìm xe gần nhất
//			agent nearest_car <- first(blocking_cars sort_by (each.location distance self.location));
//			
//			if (nearest_car != nil) {
//				// Nếu xe phía trước đang chạy
//				if (nearest_car.speed > 0) {
//					speed <- nearest_car.speed; // [cite: 172]
//					do slow_down; // [cite: 173]
//				} 
//				// Nếu xe phía trước đứng yên (xe hỏng)
//				else {
//					loop while : (speed > 0.05) { // [cite: 10, 174]
//						do slow_down;
//					}
//					
//					// Cố gắng chuyển làn ngay lập tức
//					if (location.y = target_lane_y) {
//						do choose_new_lane; // 
//					}
//				}
//			}
//		}
//	}

	// --- Hành động: Chọn làn mới
	action choose_new_lane { // 
		list<float> other_lanes;
		if (is_left_direction) {
			car_lanes_left >> location.y;
			other_lanes <- car_lanes_left; // 
		} else {
			car_lanes_right >> location.y;
			other_lanes <- car_lanes_right; // 
		}
		
		if (length(other_lanes) > 0) { // 
			// Tìm làn gần nhất
			float min_dist <- min(other_lanes collect abs(each - location.y));
			list<float> closest_lanes <- other_lanes where (abs(each - location.y) = min_dist);
			target_lane_y <- one_of(closest_lanes); // 
			patience <- max_patience; // Reset kiên nhẫn 
		}
	}
	
	// --- Hành động: Di chuyển sang làn mục tiêu
	action move_to_target_lane { // 
		// Đơn giản hóa: di chuyển trực tiếp theo trục Y
		// (NetLogo dùng cách đổi heading 45/135/225/315 độ)
		
		// Kiểm tra xe cản khi chuyển làn
		float angle <- (is_left_direction ? 90.0:270.0);
	    geometry observation_cone <- 
		    cone(int(observation_distance), int(observation_angle))
		    rotated_by angle;
		list<car> blocking_cars <- car overlapping observation_cone;
		//list<agent> blocking_cars <- self neighbors_at (abs(location.y - target_lane_y) + 2.0) angle: observation_angle;
		
		if (length(blocking_cars) = 0) {
			// Di chuyển từ từ sang làn
			float new_y;
			if (location.y < target_lane_y) {
				new_y <- min(location.y + change_lane_step, target_lane_y);
			} else if (location.y > target_lane_y) {
				new_y <- max(location.y - change_lane_step, target_lane_y);
			}
			location <- {location.x, new_y};
		} else {
			// Nếu có xe cản, giảm tốc và đợi [cite: 213]
			do slow_down;
		}
	}
}

// --- Thí nghiệm (GUI) ---
experiment TrafficGUI type: gui {
	parameter "Số làn mỗi chiều: " var: number_of_lanes_way min: 1 max: 5;
	parameter "Số lượng xe: " var: number_of_cars min: 1 max: 500;
	parameter "Gia tốc: " var: acceleration min: 0.001 max: 0.01;
	parameter "Giảm tốc: " var: deceleration min: 0.001 max: 0.1;
	parameter "Kiên nhẫn tối đa: " var: max_patience min: 10 max: 100; //
	
	
	
	

	// --- Hiển thị
	output {
		display main_display {
			// 1. Vẽ đường
			draw road_shape color: #gray border: #darkgray; // 
			
			// 2. Vẽ dải phân cách
			draw line([{0, 0}, {world.width, 0}]) color: #green size: lane_width; // 
			
			// 3. Vẽ vạch kẻ làn (đường đứt)
			loop y_lane_val in: (car_lanes_left + car_lanes_right) {
				draw line([{0, y_lane_val - (lane_width / 2.0)}, {world.width, y_lane_val - (lane_width / 2.0)}])  color: #white; // 
				draw line([{0, y_lane_val + (lane_width / 2.0)}, {world.width, y_lane_val + (lane_width / 2.0)}])  color: #white; // 
			}
			
			// 4. Vẽ các xe
			species car aspect: default;
		}
		
		// Monitor (Giám sát)
		monitor "Tốc độ trung bình" value: mean(car collect each.speed) * 100.0; // 
		monitor "Số xe" value: length(car);
	}
}