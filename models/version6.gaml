/**
* Name: version6
* Based on the internal empty template. 
* Author: Admin
* Tags: 
*/


/**
 * Tên mô hình: Expressways
 * Tác giả: Chuyển đổi cơ bản sang GAML bởi Gemini (dựa trên mã NetLogo Expressways.nlogo)
 * Ngày: 23-10-2025
 * Mô tả: Mô phỏng giao thông cao tốc hai chiều cơ bản dựa trên mô hình NetLogo.
 * Phiên bản GAMA: 1.9.x (tương thích với 2025-06)
 */
model Expressways

global {
	// --- Thiết lập Môi trường ---
	float world_width <- 100.0; // Chiều rộng thế giới (tương đương NetLogo min/max pxcor)
	float world_height <- 30.0; // Chiều cao thế giới (tương đương NetLogo min/max pycor)
	geometry shape <- envelope(world_width, world_height); // Tạo hình chữ nhật cho thế giới
	
	// --- Tham số từ NetLogo UI ---
	int number_of_lanes_way <- 5 parameter "Số làn mỗi chiều" min: 1 max: 8; // 
	int number_of_cars <- 100 parameter "Số lượng xe" min: 1 max: 500; // 
	float acceleration <- 0.005 parameter "Gia tốc" min: 0.001 max: 0.01; // 
	float deceleration <- 0.02 parameter "Giảm tốc" min: 0.001 max: 0.1; // 
	int max_patience <- 50 parameter "Kiên nhẫn tối đa" min: 10 max: 100; // 
	bool dynamic_situation <- true parameter "Tình huống động (thêm/xóa xe)?"; // 
	float prob_add_car <- 0.005 parameter "Xác suất thêm xe" min: 0.0 max: 0.1; // 

	// --- Biến Toàn cục (Tính toán từ tham số) ---
	int number_of_lanes; // [cite: 5]
	list<float> car_lanes_left; // [cite: 7]
	list<float> car_lanes_right; // [cite: 8]
	list<float> car_lanes; // [cite: 190]
	
	float speed_max <- 1.0; // 
	float speed_min <- 0.0;
	float speed_ratio <- 0.35; // [cite: 38]
	float observation_distance <- 2.5; // [cite: 24]
	float observation_angle <- 60.0; // [cite: 25]
	float change_lane_step <- 0.08; // 

	// --- Logic Khởi tạo (Setup) ---
	init {
		// Tính toán tọa độ các làn đường dựa trên mã NetLogo 
		// Giả sử mỗi "làn" trong NetLogo (ví dụ: pycor 2, 4, 6) cách nhau 2 đơn vị
		// Và dải phân cách là 0, lề là +/- (number_of_lanes - 1)
		number_of_lanes <- (number_of_lanes_way * 2 + 3);
		car_lanes_left <- n_values(number_of_lanes_way, i -> 2.0 * (i - number_of_lanes_way)); // y âm
		car_lanes_right <- n_values(number_of_lanes_way, i -> 2.0 * (number_of_lanes_way - (i + 1) + 1)); // y dương
		car_lanes <- car_lanes_left + car_lanes_right;
		
		// Tạo xe ban đầu 
		create car number: number_of_cars {
			// Đặt xe ngẫu nhiên trên một làn đường 
			location.y <- one_of(car_lanes);
			location.x <- rnd(world_width) - (world_width / 2.0);
			target_lane <- location.y;
			
			// Thiết lập thuộc tính ban đầu
			speed_top <- speed_max; // Đơn giản hóa so với NetLogo
			speed <- 0.75 + rnd(speed_top - 0.75); // 
			patience <- max_patience / 2 + rnd(max_patience / 2); // 
			
			// Đặt hướng đi (heading)
			// 0 độ: đi sang phải (y < 0), 180 độ: đi sang trái (y > 0)
			is_left_lane <- location.y < 0;
			heading <- is_left_lane ? 0.0 : 180.0;
		}
	}

	// --- Logic chạy mỗi bước (Go) ---
	reflex adjust_population {
		// Logic động để thêm/bớt xe [cite: 43, 192]
		if (dynamic_situation) {
			// Thêm xe
			if (flip(prob_add_car) and length(car) < number_of_cars) { // [cite: 44]
				bool add_left_lane <- flip(0.5);
				float start_y <- one_of(add_left_lane ? car_lanes_left : car_lanes_right);
				float start_x <- add_left_lane ? (-world_width / 2.0 + 1) : (world_width / 2.0 - 1);
				
				create car {
					location <- {start_x, start_y};
					target_lane <- location.y;
					speed_top <- speed_max;
					speed <- 0.75 + rnd(speed_top - 0.75);
					patience <- max_patience / 2 + rnd(max_patience / 2);
					is_left_lane <- location.y < 0;
					heading <- is_left_lane ? 0.0 : 180.0;
				}
			}
			// Xóa xe
			if (length(car) > number_of_cars) {
				ask one_of(car) { do die; } // 
			}
		}
	}
}

// --- Định nghĩa Tác nhân Xe (Car Species) ---
species car {
	// --- Thuộc tính ---
	float speed; // 
	float speed_top; // 
	float target_lane; // 
	int patience; // 
	bool is_left_lane;

	// --- Logic di chuyển chính (từ move-forward-greedy)  ---
	reflex move {
		// 1. Kiểm tra kiên nhẫn và quyết định chuyển làn 
		if (patience <= 0) {
			do choose_new_lane;
		}
		
		// 2. Nếu không ở đúng làn, thực hiện di chuyển làn 
		if (abs(location.y - target_lane) > 0.01) {
			do move_to_target_lane;
		} 
		// 3. Nếu ở đúng làn, lái xe bình thường
		else {
			// Đảm bảo hướng đi đúng
			heading <- is_left_lane ? 0.0 : 180.0;
			
			// Tăng tốc [cite: 149]
			do speed_up_car;
			
			// Xử lý xe cản đường 
			do handle_blocking_cars;
			
			// Di chuyển 
			do move speed: speed * speed_ratio;
			
			// Xử lý xe ra khỏi biên (quay vòng)
			if (location.x > world_width / 2.0) { location.x <- -world_width / 2.0; }
			if (location.x < -world_width / 2.0) { location.x <- world_width / 2.0; }
		}
	}

	// --- Các hành động (Actions) ---

	// Tăng tốc 
	action speed_up_car {
		speed <- min([speed + acceleration, speed_top]);
	}

	// Giảm tốc [cite: 184]
	action slow_down_car {
		if (speed > deceleration) {
			speed <- max([speed - deceleration, speed_min]);
			patience <- max([patience - 1, 0]); // [cite: 185]
		}
	}

	// Xử lý xe cản đường 
	action handle_blocking_cars {
		// Nhận diện các xe trong tầm nhìn (cone)
		list<car> blocking_cars <- car overlapping (cone(observation_distance, observation_angle));
		
		if (blocking_cars != []) {
			// Tìm xe gần nhất 
			car blocking_car_nearest <- first(blocking_cars as list sort_by (each.location distance self.location));
			
			if (blocking_car_nearest != nil) {
				// Nếu xe gần nhất đang chạy, khớp tốc độ và đi chậm hơn một chút
				speed <- blocking_car_nearest.speed; // [cite: 172]
				do slow_down_car; // [cite: 173]
			}
		}
	}

	// Chọn làn mới [cite: 208]
	action choose_new_lane {
		list<float> other_lanes <- (is_left_lane ? car_lanes_left : car_lanes_right) - location.y; // [cite: 209]
		
		if (other_lanes != []) {
			// Tìm các làn gần nhất [cite: 210]
			float min_dist <- min(other_lanes collect abs(each));
			list<float> closest_lanes <- (other_lanes where (abs(each) = min_dist)) collect (each + location.y);
			
			target_lane <- one_of(closest_lanes); // [cite: 210]
			patience <- max_patience; // [cite: 210]
		}
	}

	// Di chuyển đến làn mục tiêu 
	action move_to_target_lane {
		// Đơn giản hóa logic của NetLogo: di chuyển về phía một điểm trên làn mục tiêu
		float target_x <- location.x + (is_left_lane ? 5.0 : -5.0); // Một điểm hơi ở phía trước
		point target_point <- {target_x, target_lane};
		
		// Thay đổi hướng đi và di chuyển một bước nhỏ
		heading <- (location angle_between target_point);
		do move forward: change_lane_step;

		// Nếu đã đến rất gần, gán thẳng vào làn (để tránh lỗi số thực) [cite: 212]
		if (abs(location.y - target_lane) < change_lane_step) {
			location.y <- target_lane;
			heading <- is_left_lane ? 0.0 : 180.0; // Đặt lại hướng đi chuẩn
		}
	}
	
	// --- Hiển thị (Aspect) ---
	aspect "car_top" { // 
		// GAMA có hình dạng 'car' tích hợp sẵn.
		// NetLogo dùng "car-top"[cite: 320], là hình nhìn từ trên xuống.
		// Ta có thể dùng hình 'car' và xoay 90 độ, hoặc dùng hình vuông đơn giản.
		draw shape.car color: #white size: 1.0; 
	}
}


// --- Định nghĩa Hiển thị (Display) ---
experiment main type: gui {
	output {
		// --- Hiển thị 2D ---
		display main_display type: 2d {
			// Vẽ nền (mặt đất) 
			draw rectangle(world_width, world_height) color: #brown border: #black;
			
			// Vẽ đường (màu xám) [cite: 196]
			float road_height <- (number_of_lanes - 2) * 1.0; // Giả sử lề rộng 1
			draw rectangle(world_width, road_height) color: #gray;
			
			// Vẽ dải phân cách (màu xanh) 
			draw line([{ -world_width / 2.0, 0.0 }, { world_width / 2.0, 0.0 }]) color: #green size: 2;
			
			// Vẽ vạch kẻ làn (trắng, đứt) [cite: 203]
			loop y_coord over: (car_lanes_left + car_lanes_right) {
				if (y_coord != min(car_lanes_left) and y_coord != max(car_lanes_right)) {
					float y_line <- y_coord + (y_coord > 0 ? -1.0 : 1.0); // Vạch nằm giữa các làn
					draw line([{ -world_width / 2.0, y_line }, { world_width / 2.0, y_line }]) color: #white dashed: true;
				}
			}
			
			// Vẽ các xe
			species car;
		}
		
		// --- Biểu đồ (tương tự NetLogo Plot "Speed") [cite: 231] ---
		chart "Speed" type: series {
			data "Average" value: car mean (each.speed) * 100 color: #green;
			data "Max" value: (length(car) > 0 ? car max (each.speed) : 0) * 100 color: #cyan;
			data "Min" value: (length(car) > 0 ? car min (each.speed) : 0) * 100 color: #blue;
		}
	}
}