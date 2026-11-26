/**
* Name: version5
* Based on the internal empty template. 
* Author: Admin
* Tags: 
*/


/**
 * Tên mô hình: Simple Expressway (Phiên bản đơn giản hóa)
 * Tác giả: Chuyển đổi bởi AI (dựa trên mô hình NetLogo gốc)
 *
 * MÔ TẢ:
 * Đây là phiên bản mô phỏng giao thông đường cao tốc đơn giản,
 * loại bỏ tất cả các thuật toán Học Tăng Cường và các tình huống động (xe hỏng).
 *
 * Các xe chỉ tuân theo chính sách "Greedy":
 * 1. Cố gắng đạt tốc độ tối đa (speed_top).
 * 2. Nếu có xe phía trước, chúng sẽ giảm tốc độ để tránh va chạm .
 * 3. Mỗi khi phanh, sự kiên nhẫn (patience) giảm đi[cite: 185].
 * 4. Khi kiên nhẫn bằng 0, chúng sẽ cố gắng đổi làn [cite: 150, 208-210].
 */
model SimpleExpressway

global {
	// --- Thiết lập Môi trường ---
	// Giữ nguyên hệ tọa độ NetLogo (-30..30 cho x, -15..15 cho y)
	shape <- envelope({-30.5, -15.5}, {30.5, 15.5});
	float world_width <- 61.0;
	float world_height <- 31.0;

	// --- Biến Toàn cục (Đơn giản hóa) ---
	agent selected_car;
	int nb_cars_max;
	int number_of_lanes; // Tổng số làn
	list<float> lanes; // Tọa độ y của các vạch kẻ đường
	list<float> car_lanes; // Tọa độ y của các làn xe có thể chạy
	list<float> car_lanes_left; // Các làn bên trái (y < 0)
	list<float> car_lanes_right; // Các làn bên phải (y > 0)

	// Thông số vật lý
	float speed_max;
	float speed_min;
	float speed_ratio; // Tỷ lệ điều chỉnh tốc độ (khoảng cách/bước)
	float collision_distance;

	// Thông số đổi làn
	float change_lane_step; // Bước tiến khi đổi làn [cite: 18]

	// Thông số quan sát
	float observation_max; // Tầm nhìn xa tối đa [cite: 23]
	float observation_distance; // Tầm nhìn gần để tránh va chạm [cite: 24]
	float observation_angle; // Góc nhìn [cite: 25]

	// --- Tham số từ Giao diện (Sliders) ---
	int number_of_cars init: 111; // Số lượng xe [cite: 243]
	int number_of_lanes_way init: 5; // Số làn mỗi chiều
	float max_patience init: 50.0; // Kiên nhẫn tối đa [cite: 247]
	float acceleration init: 0.005; // Gia tốc [cite: 245]
	float deceleration init: 0.02; // Giảm tốc (phanh) [cite: 246]
	
	// --- Hành động Khởi tạo (Setup) ---
	init {
		// Dịch từ 'to setup' (phần cơ bản)
		number_of_lanes <- (number_of_lanes_way * 2 + 3); // 5 làn mỗi chiều -> 13 làn tổng cộng
		nb_cars_max <- round(number_of_lanes_way * 1.5 * world_width * 0.25);

		speed_max <- 1.0; // ~ 120 km/h [cite: 37]
		speed_min <- 0.0;
		speed_ratio <- 0.35; 
		collision_distance <- 1.0;

		change_lane_step <- 0.08; 

		observation_max <- world_width / 2; 
		observation_distance <- 2.5; 
		observation_angle <- 60; 

		// 1. Vẽ đường (tính toán tọa độ)
		do draw_road;
		// 2. Tạo xe
		do create_cars;

		// 3. Chọn một xe để theo dõi
		if length(car) > 0 {
			selected_car <- one_of(car);
			ask selected_car { color <- #pink; }
		}
	}
	
	// Hàm (reporter) lấy màu xe
	rgb get_car_default_color(car aCar) {
		if (aCar = selected_car) { return #pink; }
		if (location.y < 0) {
		    return #blue;   // Làn trái
		} else {
		    return #red;    // Làn phải
		}
//		float gray_val <- 0.8 + rnd(0.2);
//		return rgb(gray_val * 255, gray_val * 255, gray_val * 255);
	}

	// --- Vòng lặp Chính (Go) ---
	reflex global_step {
		// Yêu cầu tất cả các xe thực hiện hành vi 'Greedy'
		ask car {
			do move_forward_greedy;
		}
	}

	// --- Các hành động Tiện ích Toàn cục ---

	// Tính toán tọa độ các làn đường
	action draw_road {
		// Tính tọa độ y cho các vạch kẻ
		lanes <- [];
		loop n from: 0 to: number_of_lanes - 1 {
			lanes <- lanes + (number_of_lanes - (n * 2) - 1);
		}

		// Tính tọa độ y cho các làn xe chạy
		list<float> temp_car_lanes <- [];
		loop n from: 0 to: (number_of_lanes - 2) - 1 {
			temp_car_lanes <- temp_car_lanes + (number_of_lanes - (n * 2) - 3);
		}
		// Loại bỏ dải phân cách (y=0) khỏi danh sách làn xe chạy
		int remove_index <- number_of_lanes_way;
		if (remove_index >= 0 and remove_index < length(temp_car_lanes)) {
			temp_car_lanes <- temp_car_lanes - temp_car_lanes[remove_index];
		}
		car_lanes <- temp_car_lanes;
		
		// Chia thành làn trái và phải
		car_lanes_right <- [];
		loop n from: 0 to: number_of_lanes_way - 1 {
			car_lanes_right <- car_lanes_right + (2 * (number_of_lanes_way - n));
		}
		car_lanes_left <- [];
		loop n from: 0 to: number_of_lanes_way - 1 {
			car_lanes_left <- car_lanes_left + (2 * (n - number_of_lanes_way));
		}
	}

	// Vẽ đường (được gọi bởi 'display' trong 'experiment')
	// Tương đương 'draw-road-lines' [cite: 199-207]
	action draw_road_graphics {
		float min_x <- -30.5;
		float max_x <- 30.5;
		
		// Vẽ nền đường (màu xám) [cite: 196]
		draw rectangle(world_width, (number_of_lanes * 2.0) - 1.0) color: #gray border: #black at: {0,0};
		
		// Vẽ vạch kẻ đường
		float y <- (last(lanes)) - 1.0;
		loop while: (y <= (first(lanes) + 1.0)) {
			if (!(y in lanes)) {
				rgb line_color <- #white;
				bool dashed <- true;
				
				if (abs(y) = number_of_lanes) {
					line_color <- #yellow; // Lề đường [cite: 201]
					dashed <- false;
				} else if (abs(y) = (number_of_lanes - 2) or abs(y) = 1) {
					line_color <- #white; // Làn cứu hộ [cite: 202]
					dashed <- false;
				} else {
					line_color <- #white; // Giữa các làn [cite: 203]
					dashed <- true;
				}
				
				// Vẽ đường
				if (dashed) {
					float dash_length <- 1.0;
					float gap_length <- 0.5;
					float current_x <- min_x;
					loop while: (current_x < max_x) {
						draw line([{current_x, y}, {min(current_x + dash_length, max_x), y}]) color: line_color width: 0.1;
						current_x <- current_x + dash_length + gap_length;
					}
				} else {
					draw line([{min_x, y}, {max_x, y}]) color: line_color width: 0.1;
				}
			}
			y <- y + 1.0;
		}
		
		// Vẽ dải phân cách (màu xanh) [cite: 198]
		draw rectangle(world_width, 1.0) color: #green at: {0,0};
	}

	// Tạo xe (Đơn giản hóa từ 'create-or-remove-cars') [cite: 189-192]
	action create_cars {
		float car_speed_seed <- 0.75;

		create car number: number_of_cars {
			// Chọn một làn ngẫu nhiên trong các làn xe chạy
			float start_y <- one_of(car_lanes);
			// Đặt vị trí x ngẫu nhiên
			point start_loc <- { (rnd(world_width) - 30), start_y };
			
			// Tìm vị trí trống (đơn giản hóa 'free-car' [cite: 193])
			if (empty(car at_distance 1 overlapping start_loc)) {
				
			}
			loop while: (!empty(car at_distance 1 overlapping start_loc)) {
				start_loc <- { (rnd(world_width) - 30), start_y };
			}
			location <- start_loc;
			
			// Thiết lập hướng đi
			if (location.y < 0) { // Làn trái (y<0) đi về Đông (GAMA heading = 0)
				angle <- 0.0;
			} else { // Làn phải (y>0) đi về Tây (GAMA heading = 180)
				angle <- 180.0;
			}
			
			target_lane <- location.y;
			color <- ((location.y < 0)? #blue : #red);
			//color <- get_car_default_color(newCar);
			speed <- car_speed_seed + rnd(speed_max - car_speed_seed); 
			speed_top <- speed_max;
			patience <- (max_patience / 2) + rnd(max_patience / 2);
		}
	}
}

// --- Loài `car` (Tương đương 'breed [cars car]') ---
species car {
	// --- Biến (Attributes) ---
	// Tương đương 'cars-own' [cite: 27-31]
	float angle; // hướng đi
	float speed; // Tốc độ hiện tại [cite: 28]
	float speed_top; // Tốc độ tối đa mong muốn [cite: 29]
	float target_lane; // Làn đường muốn đến [cite: 30]
	float patience; // Mức độ kiên nhẫn [cite: 31]
	
	// --- Hình ảnh (Aspect) ---
	aspect default {
		// Vẽ hình dạng xe, kích thước 1.0, tô màu, và xoay theo hướng đi
		draw car(1) size: 1.0 color: color rotate: angle;
	}
	
	// --- Hành vi (Actions) ---

	// Hành vi lái xe Greedy [cite: 147-152]
	action move_forward_greedy {
		// Đặt lại hướng đi (quan trọng vì đổi làn sẽ thay đổi heading)
		if (location.y < 0) { angle <- 0.0; } // Đông
		if (location.y > 0) { angle <- 180.0; } // Tây
		
		color <- ((location.y < 0)? #blue : #red);
		//color <- get_car_default_color(self);

		// 1. Cố gắng tăng tốc
		do speed_up_car;

		// 2. Kiểm tra xe cản
		do handle_blocking_cars;

		// 3. Di chuyển
		//do move distance: speed * speed_ratio;
		//foward (speed * speed_ratio);
		location <- location + {cos(angle), sin(angle)} * speed * 0.35;
		

		// 4. Quyết định đổi làn
		if (patience <= 0) { do choose_new_lane; } 
		// 5. Thực hiện đổi làn (nếu ycor != target_lane)
		if (location.y != target_lane) { do move_to_target_lane; }
	}

	// Xử lý xe cản 
	action handle_blocking_cars {
		// GAMA: `in_cone` {distance, angle}
		// Lấy danh sách các xe trong vùng quan sát hình nón phía trước
		list<car> blocking_cars <- (car where each != self) inside cone(self, observation_distance, observation_angle);
		//list<car> blocking_cars <- car in_cone {distance: observation_distance, angle: observation_angle};
		// Khai báo xe cản gần nhất
		car blocking_car_nearest <- nil;
		
		if not empty(blocking_cars) {
			blocking_car_nearest <- first(blocking_cars minimized_by (each.location distance self));
		}
		
		if (blocking_car_nearest != nil) {
			// Nếu có xe cản, giảm tốc độ
			// Đặt tốc độ bằng xe phía trước [cite: 172]
			if (speed > blocking_car_nearest.speed) {
				speed <- blocking_car_nearest.speed;
				do slow_down_car; // Giảm thêm một chút và giảm kiên nhẫn
			}
		}
	}

	// Tăng tốc 
	action speed_up_car {
		speed <- speed + acceleration;
		if (speed > speed_top) { speed <- speed_top; }
	}

	// Giảm tốc (Phanh) [cite: 184-185]
	action slow_down_car {
		if (speed > deceleration) {
			speed <- speed - deceleration;
			if (speed < speed_min) { speed <- speed_min; }
			patience <- patience - 1; // Mất kiên nhẫn khi phanh [cite: 185]
			if (patience < 0) { patience <- 0; }
		}
	}

	// Chọn làn mới để đổi [cite: 208-210]
	action choose_new_lane {
		list<float> other_lanes <- [];
		if (location.y < 0) { other_lanes <- car_lanes_left - location.y; }
		if (location.y > 0) { other_lanes <- car_lanes_right - location.y; }
		
		if not empty(other_lanes) {
			// Tìm làn gần nhất [cite: 210]
			list<float> dists <- other_lanes collect abs(each - location.y);
			//list<float> dists <- abs(other_lanes - location.y);
			float min_dist <- min(dists);
			list<float> closest_lanes <- other_lanes where (each in dists and dists[other_lanes index_of each] = min_dist);
			
			target_lane <- one_of(closest_lanes);
			patience <- max_patience; // Hồi lại kiên nhẫn
		}
	}

	// Di chuyển đến làn mục tiêu [cite: 211-213]
	action move_to_target_lane {
		// Dịch heading (góc lái) của NetLogo sang GAMA:
		// NetLogo: 45 (Đông-Bắc), 135 (Đông-Nam)
		// GAMA (so với heading 0 - Đông): 45, -45
		if (location.y < 0) { // Đang đi về Đông (heading 0)
			angle <- (target_lane < location.y) ? -45.0 : 45.0;
		}
		// NetLogo: 315 (Tây-Bắc), 225 (Tây-Nam)
		// GAMA (so với heading 180 - Tây): 135, -135 (hoặc 225)
		else { // Đang đi về Tây (heading 180)
			angle <- (target_lane < location.y) ? -135.0 : 135.0;
		}
		
		// Kiểm tra xe cản khi đang đổi làn
		list<car> bloacking_cars <- (car where each != self) inside cone (self, (observation_distance + abs(location.y - target_lane)), observation_angle);
		//list<car> blocking_cars <- car in_cone {distance: (observation_distance + abs(location.y - target_lane)), angle: observation_angle};
		car blocking_car_nearest <- nil;
		if not empty(blocking_cars) {
			blocking_car_nearest <- first(blocking_cars minimized_by (each.location distance self));
		}
		
		if (blocking_car_nearest = nil) {
			// Nếu không có ai, tiến về làn
			forward change_lane_step;
		} else {
			// Nếu có xe cản, tạm dừng đổi làn và phanh [cite: 213]
			do slow_down_car;
		}
		
		// GAMA không bị lỗi float như NetLogo, không cần 'precision'
	}

	// --- Hàm (Functions) ---

	// Lấy xe phía trước (Đơn giản hóa từ 'get-car-ahead' [cite: 227])
	car get_car_ahead {
		// Tìm xe phía trước trong 1 góc hẹp (30 độ) cùng làn
		//list<car> cars_ahead <- car in_cone {distance: observation_max, angle: 30} 
		list cars_ahead <- (car where each != self) inside cone (self, observation_max, 30)
			where (round(each.location.y) = round(location.y));
			
		if not empty(cars_ahead) {
			return first(cars_ahead minimized_by (each.location distance self));
		}
		return nil; // Tương đương 'nobody'
	}
}

// --- Thí nghiệm (Giao diện) ---
experiment "Simple Traffic" type: gui {
	// --- Tham số (Parameters) ---
	// Các tham số đã được định nghĩa trong 'global'
	// GAMA sẽ tự động hiển thị các biến có 'init:'
	
	// --- Đầu ra (Output) ---
	output {
		// Hiển thị chính
		display main_display type: 2d {
			// Vẽ nền đường (chỉ 1 lần)
			graphics "road" refresh: false {
				do draw_road_graphics;
			}
			// Vẽ các xe
			species car aspect: default;
		}

		// Giám sát (Monitors)
		monitor "Average Speed" value: (mean(car collect each.speed)) * 100;
		monitor "Average Patience" value: mean(car collect each.patience);
		
		// Biểu đồ (Plots)
		chart "Speed" type: series refresh: every(10 #cycles) {
			data "average" value: mean(car collect each.speed) color: #green;
			data "max" value: max(car collect each.speed) color: #cyan;
			data "min" value: min(car collect each.speed) color: #blue;
		}
		
		chart "Driver's Patience" type: series refresh: every(10 #cycles) {
			data "average" value: mean(car collect each.patience) color: #blue;
			data "max" value: max(car collect each.patience) color: #red;
			data "min" value: min(car collect each.patience) color: #orange;
		}
	}
}