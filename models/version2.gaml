/**
* Name: version2
* Based on the internal empty template. 
* Author: Admin
* Tags: 
*/


/**
 * Tên mô hình: Expressways GAML
 * Tác giả: Chuyển đổi từ mô hình NetLogo của Wilensky & Payette
 * Mô tả: Mô phỏng giao thông trên đường cao tốc đa làn sử dụng các chính sách lái xe dựa trên quy tắc và Học Tăng cường.
 */

model Expressways

global {
	// --- Tham số Môi trường và Đường ---
	int number_of_lanes_way <- 5;
	int number_of_lanes <- number_of_lanes_way * 2 + 3;
	list<float> lanes;
	list<float> car_lanes;
	list<float> car_lanes_left;
	list<float> car_lanes_right;

	// --- Tham số Xe và Giao thông ---
	int number_of_cars <- 100;
	int nb_cars_max;
	float speed_max <- 1.0; // ~ 120 km/h
	float speed_min <- 0.0;
	float speed_sudden_stop <- 0.05;
	float acceleration <- 0.005;
	float deceleration <- 0.02;

	// --- Tham số Va chạm và Hỏng hóc ---
	float collision_distance <- 1.0;
	int nb_collisions <- 0;
	rgb damaged_color <- #red;
	int damaged_inlane_duration_max <- 1800; // 30 phút
	int damaged_nb_cars_inlane <- 0;
	int max_damaged_cars <- 4;
	float prob_damaged_car <- 0.00002;

	// --- Tham số Quan sát ---
	float observation_max;
	float observation_distance <- 2.5;
	float observation_angle <- 60.0;

	// --- Tham số Chung ---
	int max_patience <- 50;
	string driving_policy <- "Greedy"; // Có thể thay đổi thành "Q-Learning", "A2C", v.v.
	
	// --- Khởi tạo Mô hình (Tương đương `setup` trong NetLogo) ---
	init {
		// --- Thiết lập các giá trị ban đầu ---
		observation_max <- world.width / 2.0;
		nb_cars_max <- round(number_of_lanes_way * 1.5 * world.width * 0.25);
		
		// --- Vẽ đường (Tương đương `draw-road`) ---
		ask patch {
			pcolor <- #brown - rgb(rnd(128), rnd(128), rnd(128)); // Nền đất
			if (abs(location.y) <= number_of_lanes) {
				pcolor <- #gray - rgb(rnd(64), rnd(64), rnd(64)); // Mặt đường
			}
			if (abs(location.y) = (number_of_lanes - 1)) {
				pcolor <- #white - rgb(100, 100, 100); // Làn cứu hộ
			}
			if (location.y = 0) {
				pcolor <- #green - rgb(64, 64, 64); // Dải phân cách
			}
		}

		// --- Tính toán tọa độ các làn xe ---
		car_lanes_right <- n_times(number_of_lanes_way) with: (each + 1) * 2.0;
		car_lanes_left <- n_times(number_of_lanes_way) with: (each + 1) * -2.0;
		car_lanes <- car_lanes_left + car_lanes_right;

		// --- Tạo xe ---
		create car number: number_of_cars {
			location <- one_of(patch where (member(each.location.y, car_lanes) and not any(car at each.location)));
			target_lane <- location.y;
			
			if (member(location.y, car_lanes_left)) {
				heading <- 90;
			} else {
				heading <- 270;
			}
			
			speed <- 0.75 + rnd(speed_max - 0.75);
			speed_top <- speed_max;
			patience <- round(max_patience / 2) + rnd(round(max_patience / 2));
		}
		
		// Ghi chú: Phần setup cho Python RL sẽ được gọi từ đây nếu cần.
		// Ví dụ: do python_setup();
	}

	// --- Bước chạy chính (Tương đương `go` trong NetLogo) ---
	reflex main_step when: driving_policy = "Greedy" {
		ask car {
			do move_forward_greedy;
		}
		nb_collisions <- length(car overlapping car) / 2;
	}
	
	// Ghi chú: Các reflex khác cho từng thuật toán RL sẽ được định nghĩa ở đây.
	// Ví dụ: reflex q_learning_step when: driving_policy = "Q-Learning" { ... }
}


// --- Định nghĩa Agent Xe (species car) ---
species car skills: [moving] {
	// --- Thuộc tính của xe ---
	float speed;
	float speed_top;
	float target_lane;
	int patience;
	int damaged_inlane_duration <- 0;
	
	// --- Thuộc tính cho RL ---
	float reward <- 0.0;
	list<float> state;
	int _action <- -1;
	list<float> next_state;
	
	// --- Giao diện hiển thị ---
	aspect default {
		draw circle(0.5) color: #white border: #black; // Thay thế bằng hình xe hơi nếu có file
	}

	// --- Hành động Lái xe theo Luật (Greedy) ---
	action move_forward_greedy {
		if (speed > 0) {
			if (flip(prob_damaged_car)) { // Xe bị hỏng
				if (damaged_nb_cars_inlane < max_damaged_cars) {
					speed <- 0.0;
					color <- damaged_color;
					damaged_inlane_duration <- 1;
					damaged_nb_cars_inlane <- damaged_nb_cars_inlane + 1;
				}
			} else { // Xe hoạt động bình thường
				if (location.y < 0) { heading <- 90; }
				if (location.y > 0) { heading <- 270; }
				
				// 1. Tăng tốc
				speed <- speed + acceleration;
				if (speed > speed_top) { speed <- speed_top; }

				// 2. Xử lý xe cản đường
				do handle_blocking_cars;

				// 3. Di chuyển
				location <- location + {cos(heading), sin(heading)} * speed * 0.35;

				// 4. Quyết định chuyển làn
				if (patience <= 0) {
					do choose_new_lane;
				}
				if (location.y != target_lane) {
					do move_to_target_lane;
				}
			}
		} else { // Xử lý xe đã bị hỏng
			do handle_damaged_car;
		}
	}

	// --- Xử lý xe cản đường ---
	action handle_blocking_cars {
		// Sử dụng cú pháp GAMA mới để tìm agent gần nhất trong hình nón
		list<car> blocking_cars <- self.agents_in_cone(observation_distance, observation_angle, car);
		if not empty(blocking_cars) {
			car blocking_car_nearest <- arg_min(blocking_cars, each.distance_to(self));
			
			if (blocking_car_nearest.speed > 0) {
				speed <- min(speed, blocking_car_nearest.speed);
			} else { // Xe phía trước bị hỏng
				if (speed > speed_sudden_stop) {
					speed <- speed - deceleration;
				}
				if (location.y = target_lane) {
					do choose_new_lane;
				}
			}
		}
	}
	
	// --- Chọn làn mới ---
	action choose_new_lane {
		list<float> other_lanes;
		if (location.y < 0) {
			other_lanes <- car_lanes_left where (each != location.y);
		} else {
			other_lanes <- car_lanes_right where (each != location.y);
		}
		
		if not empty(other_lanes) {
			// Sử dụng `with_min` để tìm làn gần nhất
			target_lane <- one_of(other_lanes) with_min (abs(each - location.y));
			patience <- max_patience;
		}
	}
	
	// --- Di chuyển sang làn mục tiêu ---
	action move_to_target_lane {
		// Logic di chuyển chéo, tương tự NetLogo
		float angle_offset <- 45.0;
		if (target_lane < location.y) {
			angle_offset <- (location.y < 0) ? 135.0 : 225.0;
		} else {
			angle_offset <- (location.y < 0) ? 45.0 : 315.0;
		}
		location <- location + {cos(angle_offset), sin(angle_offset)} * 0.08;
	}

	// --- Xử lý xe hỏng (chưa hoàn thiện, cần logic chi tiết hơn) ---
	action handle_damaged_car {
		// Logic di chuyển vào làn cứu hộ và phục hồi
	}
}


// --- Định nghĩa Thí nghiệm ---
experiment "SoSanh_QLearning_vs_A2C" type: gui {
	// --- Các tham số có thể thay đổi trên giao diện ---
	parameter "Chính sách lái xe" var: driving_policy among: ["Greedy", "Q-Learning", "A2C"];
	parameter "Số lượng xe" var: number_of_cars min: 10 max: 200 step: 10;

	// --- Các chỉ số đầu ra để theo dõi ---
	output {
		monitor "Tốc độ trung bình" value: mean(car.speed) refresh_every: 1;
		monitor "Số va chạm" value: nb_collisions refresh_every: 1;
	}
}