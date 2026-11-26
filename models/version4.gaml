/**
* Name: version4
* Based on the internal empty template. 
* Author: Admin
* Tags: 
*/


/**
 * Tên mô hình: Expressways (Chuyển đổi từ NetLogo)
 * Tác giả: Chuyển đổi bởi AI (dựa trên mô hình NetLogo gốc của Wilensky & Payette)
 * Ngày chuyển đổi: 21-10-2025
 *
 * MÔ TẢ:
 * Mô hình này mô phỏng luồng giao thông trên đường cao tốc nhiều làn,
 * triển khai cả chính sách lái xe dựa trên quy tắc (Greedy) và các thuật toán
 * Học tăng cường (RL) khác nhau (Q-Learning, DQN, Actor-Critic) để
 * điều khiển hành vi của xe.
 *
 * Ghi chú chuyển đổi quan trọng:
 * 1. PLUGIN: Sử dụng plugin Python của GAMA. Cần cài đặt `msi.gama.external.python.PythonPlugin`.
 * 2. TÊN BIẾN: Tên biến NetLogo (ví dụ: 'nb-cars-max') được đổi thành 'nb_cars_max' (snake_case)
 * để tuân thủ cú pháp GAMA.
 * 3. TỌA ĐỘ: Hệ tọa độ NetLogo (-30..30, -15..15) được bảo toàn bằng cách
 * sử dụng `shape <- envelope({-30.5, -15.5}, {30.5, 15.5});`
 * 4. GÓC LÁI (HEADING): NetLogo (0=Bắc, 90=Đông) được chuyển đổi sang GAMA (0=Đông, 90=Bắc).
 * Công thức: gama_heading = 90 - netlogo_heading.
 * 5. PYTHON: Các lệnh 'py:run', 'py:set', 'py:runresult' của NetLogo được ánh xạ tới
 * 'python.execute()', 'python.set()', 'python.eval()'.
 */
model Expressways

/* * ## TÀI LIỆU (PHẦN 1: PLUGINS VÀ MÔI TRƯỜNG TOÀN CỤC)
 *
 * 1. Plugins:
 * - Mô hình NetLogo gốc sử dụng `extensions [ py ]`.
 * - Trong GAMA, chúng ta khai báo `msi.gama.external.python.PythonPlugin`
 * để cho phép GAMA tương tác với Python, điều này rất quan trọng
 * cho các thuật toán RL.
 *
 * 2. global:
 * - Đây là nơi định nghĩa môi trường mô phỏng và các biến toàn cục.
 * - `shape`: Chúng ta sử dụng `envelope` để tái tạo chính xác thế giới
 * NetLogo (pxcor từ -30 đến 30, pycor từ -15 đến 15). Điều này làm cho
 * việc chuyển đổi tọa độ (như ycor của làn đường) trở nên trực tiếp.
 * - Biến toàn cục: Tất cả các biến trong `globals` của NetLogo được
 * khai báo ở đây. Tên biến có dấu gạch ngang (ví dụ: `nb-cars-max`)
 * được đổi thành dấu gạch dưới (ví dụ: `nb_cars_max`) vì GAMA
 * không cho phép dấu gạch ngang trong tên biến.
 * - `init`: Đây là hành động thay thế cho `to setup` của NetLogo.
 * Nó khởi tạo các biến, thiết lập Python, vẽ đường và tạo xe.
 * - `global_step`: Đây là một `reflex` (phản xạ) toàn cục, tương đương
 * với `to go` của NetLogo. Nó điều phối luồng chính của mô phỏng
 * mỗi bước thời gian (cycle). Nó kiểm tra `dynamic_situation`,
 * tạo/xóa xe, và sau đó gọi hành động RL hoặc Greedy thích hợp.
 * Cấu trúc này (điều phối từ `global`) rất quan trọng đối với
 * các thuật toán RL cần thu thập trạng thái từ tất cả các agent
 * trước khi đưa ra quyết định.
 */
plugins {
	msi.gama.external.python.PythonPlugin;
}

global {
	// Giữ nguyên hệ tọa độ NetLogo
	shape <- envelope({-30.5, -15.5}, {30.5, 15.5}); // Tương đương -30..30 (x), -15..15 (y)
	float world_width <- 61; // Tương đương max-pxcor - min-pxcor
	float world_height <- 31; // Tương đương max-pycor - min-pycor

	// Biến toàn cục từ NetLogo
	agent selected_car;
	int nb_cars_max;
	int number_of_lanes;
	list<float> lanes;
	list<float> car_lanes;
	list<float> car_lanes_left;
	list<float> car_lanes_right;

	float speed_max;
	float speed_min;
	float speed_sudden_stop;
	float speed_ratio;

	float collision_distance;
	int nb_collisions;

	rgb damaged_color;
	int damaged_inlane_duration_max;
	int damaged_inrescue_duration_max;
	int damaged_nb_cars_inlane;

	float change_lane_step;
	float move_rescue_lane_step;

	float prob_damaged_car;
	float prob_add_car;
	float prob_remove_car;

	float observation_max;
	float observation_distance;
	float observation_angle;

	// Tham số RL
	int hidden_layer_size;
	list state_env_def; // Định nghĩa trạng thái (sẽ được thay thế bằng list GAMA trực tiếp)
	int ac_update_steps;
	int number_of_cars; // Từ Slider
	int number_of_lanes_way; // Từ Slider
	float max_patience; // Từ Slider
	string driving_policy; // Từ Chooser
	float acceleration; // Từ Slider
	float deceleration; // Từ Slider
	float exp_rate; // Từ Slider
	float exp_decay; // Từ Slider
	float learning_rate; // Từ Slider
	float discount_factor; // Từ Slider
	int batch_size; // Từ Slider
	int memory_size; // Từ Slider
	bool input_exp; // Từ Switch
	bool input_time; // Từ Switch
	int max_damaged_cars; // Từ Slider
	bool multiple_workers; // Từ Switch
	bool dynamic_situation; // Từ Switch
	int simulation_steps; // Từ Slider

	// Khởi tạo mô hình
	init {
		// Dịch từ 'to setup'
		number_of_lanes <- (number_of_lanes_way * 2 + 3);
		nb_cars_max <- round(number_of_lanes_way * 1.5 * world_width * 0.25);

		speed_max <- 1.0; // ~ 120 km/h
		speed_min <- 0.0;
		speed_sudden_stop <- 0.05;
		speed_ratio <- 0.35;

		collision_distance <- 1.0;

		damaged_color <- #red;
		damaged_inlane_duration_max <- 1800; // 30 phút
		damaged_inrescue_duration_max <- 2700; // 45 phút
		damaged_nb_cars_inlane <- 0;

		change_lane_step <- 0.08;
		move_rescue_lane_step <- change_lane_step * 0.1;

		prob_damaged_car <- 0.00002;
		prob_add_car <- 0.005;
		prob_remove_car <- 0.00005;

		observation_max <- world_width / 2;
		observation_distance <- 2.5;
		observation_angle <- 60;

		hidden_layer_size <- 36;
		ac_update_steps <- 2000;

		do draw_road;
		do create_or_remove_cars;

		if length(car) > 0 {
			selected_car <- one_of(car);
			ask selected_car { color <- #pink; }
		}

		// Thiết lập Python cho RL
		if (driving_policy != "Greedy" and driving_policy != "Greedy-CL") {
			python.setup();
			python.execute("import numpy as np");
			python.execute("import os");
			python.execute("os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'");

			python.set("action_size", 4); // 0 = decelerate, 1 = stay same, 2 = accelerate, 3 = change lane
			python.set("gamma", discount_factor);
			python.set("alpha", learning_rate);

			if (driving_policy = "SARSA" or driving_policy = "Q-Learning" or driving_policy = "Double Q-Learning") {
				do setup_tabular_algos;
			}
			if (driving_policy = "Deep Q-Learning" or driving_policy = "Deep Q-Network" or driving_policy = "Double Deep Q-Network") {
				do setup_approximate_algos;
			}
			if (driving_policy = "Naive Actor-Critic" or driving_policy = "Advantage Actor-Critic" or driving_policy = "Soft Actor-Critic") {
				do setup_actor_critic_algos;
			}
			if (driving_policy = "Proximal Policy Optimization") {
				do setup_ppo;
			}
		}
		// reset-ticks và reset-timer được GAMA xử lý tự động
	}

	// Vòng lặp chính của mô phỏng
	reflex global_step {
		// Dịch từ 'to go'
		// Điều kiện dừng 'if ticks >= simulation-steps' được xử lý trong 'experiment'
		
		if (dynamic_situation) {
			if (flip(prob_add_car) and length(car) < nb_cars_max) {
				number_of_cars <- number_of_cars + 1; // Thêm xe
			}
		}

		do create_or_remove_cars;
		nb_collisions <- 0;

		// Logic điều khiển trung tâm
		if (driving_policy = "Greedy" or driving_policy = "Greedy-CL") {
			ask car { do move_forward_greedy; }
		} else if (driving_policy = "SARSA" or driving_policy = "Q-Learning") {
			do go_sarsa_qlearning;
		} else if (driving_policy = "Double Q-Learning") {
			do go_double_ql;
		} else if (driving_policy = "Deep Q-Learning" or driving_policy = "Deep Q-Network" or driving_policy = "Double Deep Q-Network") {
			do go_approximate_algos;
		} else if (driving_policy = "Naive Actor-Critic") {
			do go_nac;
		} else if (driving_policy = "Advantage Actor-Critic") {
			if (multiple_workers) {
				do go_a2c_with_workers;
			} else {
				do go_a2c_without_workers;
			}
		} else if (driving_policy = "Soft Actor-Critic") {
			do go_sac;
		} else if (driving_policy = "Proximal Policy Optimization") {
			do go_ppo;
		}
	}

	// --- Các hành động thiết lập RL (Chuyển đổi từ NetLogo 'to setup-...') ---

	action setup_tabular_algos {
		// state-env được định nghĩa trực tiếp trong GAMA khi lấy trạng thái
		int state_size <- (max_patience + 1) * 101 * world_width * 101;
		python.set("state_size", state_size);

		if (driving_policy = "SARSA" or driving_policy = "Q-Learning") {
			python.execute("Q = np.zeros([state_size, action_size])"); // Bảng Q
		}
		if (driving_policy = "Double Q-Learning") {
			python.execute("QA = np.zeros([state_size, action_size])"); // Bảng QA
			python.execute("QB = np.zeros([state_size, action_size])"); // Bảng QB
		}
	}

	action setup_approximate_algos {
		// state-env được định nghĩa trực tiếp trong GAMA
		int input_state_size <- 5; // speed, dist_ahead, speed_ahead, dist_behind, speed_behind
		if (input_exp) { input_state_size <- input_state_size + 1; }
		if (input_time) { input_state_size <- input_state_size + 1; }

		python.set("input_state_size", input_state_size);
		python.set("hidden_layer_size", hidden_layer_size);
		python.set("memory_size", memory_size);
		python.set("batch_size", batch_size);

		python.execute("import tensorflow as tf");
		python.execute("from tensorflow import keras");
		python.execute("from keras import layers");

		// Q Network
		python.execute("Q_network = keras.Sequential()");
		python.execute("Q_network.add(layers.Dense(hidden_layer_size, input_shape=(input_state_size,), activation='relu'))");
		python.execute("Q_network.add(layers.Dense(hidden_layer_size, activation='relu'))");
		python.execute("Q_network.add(layers.Dense(hidden_layer_size, activation='relu'))");
		python.execute("Q_network.add(layers.Dense(action_size))");
		python.execute("optimizer = keras.optimizers.Adam(learning_rate=alpha)");
		python.execute("Q_network.compile(optimizer, 'mse')");
		
		// Bộ nhớ chia sẻ
		python.execute("memory = []");

		if (driving_policy = "Deep Q-Network" or driving_policy = "Double Deep Q-Network") {
			python.set("update_steps", 1000);
			python.set("step", 0);
			python.execute("Q_hat_network = keras.models.clone_model(Q_network)");
		}
	}

	action setup_actor_critic_algos {
		// state-env được định nghĩa trực tiếp trong GAMA
		int input_state_size <- 5;
		if (input_exp) { input_state_size <- input_state_size + 1; }
		if (input_time) { input_state_size <- input_state_size + 1; }
		
		python.set("input_state_size", input_state_size);
		python.set("hidden_layer_size", 36);

		python.execute("import tensorflow as tf");
		python.execute("import tensorflow_probability as tfp");
		python.execute("from tensorflow import keras");
		python.execute("from keras import layers");
		python.execute("import tensorflow.keras.losses as kls");

		// Mạng Actor
		python.execute("Actor_network = keras.Sequential()");
		python.execute("Actor_network.add(layers.Dense(hidden_layer_size, input_shape=(input_state_size,), activation='relu'))");
		python.execute("Actor_network.add(layers.Dense(hidden_layer_size, activation='relu'))");
		python.execute("Actor_network.add(layers.Dense(hidden_layer_size, activation='relu'))");
		python.execute("Actor_network.add(layers.Dense(action_size, activation='softmax'))");
		python.execute("a_optimizer = keras.optimizers.Adam(learning_rate=alpha)");
		python.execute("Actor_network.compile(a_optimizer, 'mse')");

		// Mạng Critic
		python.execute("Critic_network = keras.Sequential()");
		python.execute("Critic_network.add(layers.Dense(hidden_layer_size, input_shape=(input_state_size,), activation='relu'))");
		python.execute("Critic_network.add(layers.Dense(hidden_layer_size, activation='relu'))");
		python.execute("Critic_network.add(layers.Dense(hidden_layer_size, activation='relu'))");
		python.execute("Critic_network.add(layers.Dense(1))");
		python.execute("c_optimizer = keras.optimizers.Adam(learning_rate=alpha)");
		python.execute("Critic_network.compile(c_optimizer, 'mse')");

		if (driving_policy = "Advantage Actor-Critic") {
			python.set("update_steps", ac_update_steps);
			python.set("step", 0);
			int max_who <- 0;
			if length(car) > 0 { max_who <- max(car collect each.name); } // GAMA dùng 'name' (string) hoặc 'self' (agent)
			// Giả định 'who' là chỉ số. GAMA không có 'who'. Chúng ta sẽ dùng kích thước list.
			python.set("nb_cars", length(car)); // Sửa đổi so với NetLogo
			python.set("update_offset", round(ac_update_steps / max(1, length(car))));

			if (multiple_workers) {
				// Triển khai A2C với
				// worker
				python.execute("from multiprocessing import Process, Queue, Barrier, Lock");
				python.execute("barrier = Barrier(number_workers)"); // 'number_workers' cần được định nghĩa
				python.execute("s_queue = Queue()");
				python.execute("a_queue = Queue()");
				python.execute("r_queue = Queue()");
				python.execute("lock = Lock()");
				python.execute("processes = []");
			} else {
				// A2C không có worker
				python.execute("mem_states = [[] for i in range(nb_cars)]");
				python.execute("mem_rewards = [[] for i in range(nb_cars)]");
				python.execute("mem_actions = [[] for i in range(nb_cars)]");
				python.execute("mem_returns = [[] for i in range(nb_cars)]");
			}
		}

		if (driving_policy = "Soft Actor-Critic") {
			python.set("memory_size", memory_size);
			python.set("batch_size", batch_size);
			python.set("nb_cars", length(car));

			// Mạng Critic2
			python.execute("Critic2_network = keras.Sequential()");
			python.execute("Critic2_network.add(layers.Dense(hidden_layer_size, input_shape=(input_state_size,), activation='relu'))");
			python.execute("Critic2_network.add(layers.Dense(hidden_layer_size, activation='relu'))");
			python.execute("Critic2_network.add(layers.Dense(hidden_layer_size, activation='relu'))");
			python.execute("Critic2_network.add(layers.Dense(1))");
			python.execute("c2_optimizer = keras.optimizers.Adam(learning_rate=alpha)");
			python.execute("Critic2_network.compile(c2_optimizer, 'mse')");

			// Mạng Value
			python.execute("Value_network = keras.Sequential()");
			// ... (Tương tự Critic2)
			python.execute("v_optimizer = keras.optimizers.Adam(learning_rate=alpha)");
			python.execute("Value_network.compile(v_optimizer, 'mse')");

			// Mạng Target Value
			python.execute("Target_Value_network = keras.Sequential()");
			// ... (Tương tự Critic2)
			python.execute("Target_Value_network.compile(v_optimizer, 'mse')");
			
			// Bộ nhớ
			python.execute("memory = []");
			// ...
		}
	}

	action setup_ppo {
		// Tương tự setup_actor_critic_algos
		// (Lược bỏ để tiết kiệm không gian, logic giống hệt)
	}

	// --- Các hành động RL chính (Chuyển đổi từ NetLogo 'to go-...') ---
	// Đây là các hành động TOÀN CỤC điều phối agent

	action go_sarsa_qlearning {
		float current_epsilon <- get_epsilon();
		ask car where (each.speed > 0) {
			// Lấy trạng thái
			list current_state <- [patience, round(100 * speed), round(get_distance_to_car(get_car_ahead())), round(100 * get_speed_to_car(get_car_ahead()))];
			int state_int <- convert_state_int(current_state);
			python.set("state", state_int);

			// Chọn hành động e-greedy
			if (0.05 + rnd(1.0)) < current_epsilon {
				action <- rnd(4);
				loop while (action = 3 and patience > 0) { action <- rnd(4); }
			} else {
				action <- int(python.eval("np.argmax(Q[state,:])"));
			}
			python.set("action", action);

			// Thực hiện hành động
			do move_forward_rl;
			python.set("reward", reward);

			// Lấy trạng thái tiếp theo
			list next_s <- [patience, round(100 * speed), round(get_distance_to_car(get_car_ahead())), round(100 * get_speed_to_car(get_car_ahead()))];
			int next_state_int <- convert_state_int(next_s);
			python.set("next_state", next_state_int);

			// Cập nhật Q-table
			if (driving_policy = "SARSA") {
				int next_action <- int(python.eval("np.argmax(Q[next_state,:])"));
				if (0.05 + rnd(1.0)) < current_epsilon {
					next_action <- rnd(4);
					loop while (next_action = 3 and patience > 0) { next_action <- rnd(4); }
				}
				python.set("next_action", next_action);
				python.execute("Q[state,action] += alpha * (reward + gamma * Q[next_state,next_action] - Q[state,action])");
			}
			if (driving_policy = "Q-Learning") {
				python.execute("Q[state,action] += alpha * (reward + gamma * np.max(Q[next_state,:]) - Q[state,action])");
			}
		}
		ask car where (each.speed = 0) {
			do handle_damaged_car;
		}
	}

	action go_double_ql {
		float current_epsilon <- get_epsilon();
		ask car where (each.speed > 0) {
			// Lấy trạng thái
			list current_state <- [patience, round(100 * speed), round(get_distance_to_car(get_car_ahead())), round(100 * get_speed_to_car(get_car_ahead()))];
			int state_int <- convert_state_int(current_state);
			python.set("state", state_int);

			// Chọn hành động
			if (0.05 + rnd(1.0)) < current_epsilon {
				action <- rnd(4);
				loop while (action = 3 and patience > 0) { action <- rnd(4); }
			} else {
				action <- int(python.eval("np.argmax( (QA[state,:] + QB[state,:])/2 )"));
			}
			python.set("action", action);

			// Thực hiện hành động
			do move_forward_rl;
			python.set("reward", reward);

			// Lấy trạng thái tiếp theo
			list next_s <- [patience, round(100 * speed), round(get_distance_to_car(get_car_ahead())), round(100 * get_speed_to_car(get_car_ahead()))];
			int next_state_int <- convert_state_int(next_s);
			python.set("next_state", next_state_int);

			// Cập nhật QA, QB
			if flip(0.5) { // Cập nhật QA
				python.execute("next_action = np.argmax(QA[next_state,:])");
				python.execute("QA[state,action] += alpha * (reward + gamma * np.max(QB[next_state,next_action]) - QA[state,action])");
			} else { // Cập nhật QB
				python.execute("next_action = np.argmax(QB[next_state,:])");
				python.execute("QB[state,action] += alpha * (reward + gamma * np.max(QA[next_state,next_action]) - QB[state,action])");
			}
		}
		ask car where (each.speed = 0) {
			do handle_damaged_car;
		}
	}

	action go_approximate_algos {
		// 1. Lấy trạng thái cho tất cả xe
		list<car> car_list <- car where (each.speed > 0);
		list<list<float>> states <- [];
		ask car_list {
			list s <- [speed, get_distance_to_car(get_car_ahead()), get_speed_to_car(get_car_ahead()), get_distance_to_car(get_car_behind()), get_speed_to_car(get_car_behind())];
			if (input_exp) { s <- s + get_epsilon(); }
			if (input_time) { s <- s + cycle; }
			state <- s;
			states <- states + s;
		}
		python.set("states", states);

		// 2. Agent chọn hành động (e-greedy)
		if empty(states) { return; }
		list<int> actions <- (list<int>) python.eval("np.argmax(Q_network.predict(np.array(states), verbose=0), axis = 1)");
		float current_epsilon <- get_epsilon();
		loop i from: 0 to: length(car_list) - 1 {
			car agent_t <- car_list[i];
			if (0.05 + rnd(1.0)) < current_epsilon {
				agent_t.action <- rnd(4);
				loop while (agent_t.action = 3 and agent_t.patience > 0) { agent_t.action <- rnd(4); }
			} else {
				agent_t.action <- actions[i];
			}
		}

		// 3. Thực hiện hành động và lấy trạng thái tiếp theo
		list<list> new_experience <- [];
		ask car_list {
			do move_forward_rl;
			
			list s_next <- [speed, get_distance_to_car(get_car_ahead()), get_speed_to_car(get_car_ahead()), get_distance_to_car(get_car_behind()), get_speed_to_car(get_car_behind())];
			if (input_exp) { s_next <- s_next + get_epsilon(); }
			if (input_time) { s_next <- s_next + cycle; }
			next_state <- s_next;
			
			// Thêm kinh nghiệm
			new_experience <- new_experience + [state, action, reward, next_state];
		}

		// 4. Lưu kinh nghiệm và huấn luyện mạng
		python.set("new_experience", new_experience);
		python.execute("memory.extend(new_experience)");
		python.execute("if len(memory) > memory_size: memory = memory[-memory_size:]");
		
		// Huấn luyện nếu đủ bộ nhớ
		python.execute("sample_size = min(len(memory), batch_size)");
		python.execute("if sample_size > 0: sample_ix = np.random.randint(len(memory), size = sample_size)");
		python.execute("if sample_size > 0: states = np.array([memory[i][0] for i in sample_ix])");
		python.execute("if sample_size > 0: actions = np.array([memory[i][1] for i in sample_ix])");
		python.execute("if sample_size > 0: rewards = np.array([memory[i][2] for i in sample_ix])");
		python.execute("if sample_size > 0: next_states = np.array([memory[i][3] for i in sample_ix])");
		python.execute("if sample_size > 0: targets = Q_network.predict(states, verbose=0)");

		if (driving_policy = "Deep Q-Learning") {
			python.execute("if sample_size > 0: q_values = np.max(Q_network.predict(next_states, verbose=0), axis = 1)");
		}
		if (driving_policy = "Deep Q-Network") {
			python.execute("if sample_size > 0: q_values = np.max(Q_hat_network.predict(next_states, verbose=0), axis = 1)");
		}
		if (driving_policy = "Double Deep Q-Network") {
			python.execute("if sample_size > 0: next_targets = Q_network.predict(next_states, verbose=0)");
			python.execute("if sample_size > 0: best_next_actions = np.argmax(next_targets, axis=1)");
			python.execute("if sample_size > 0: next_targets_hat = Q_hat_network.predict(next_states, verbose=0)");
			python.execute("if sample_size > 0: q_values = next_targets_hat[np.arange(len(next_targets_hat)), best_next_actions]");
		}
		
		python.execute("if sample_size > 0: targets[np.arange(targets.shape[0]), actions] = rewards + gamma*q_values");
		python.execute("if sample_size > 0: Q_network.train_on_batch(states, targets)");

		if (driving_policy = "Deep Q-Network" or driving_policy = "Double Deep Q-Network") {
			python.execute("step = step + 1");
			python.execute("if (step % update_steps == 0): Q_hat_network = keras.models.clone_model(Q_network)");
		}
	}
	
	action go_nac {
		// 1. Lấy trạng thái
		list<car> car_list <- car as list;
		list<list<float>> states <- [];
		ask car_list {
			list s <- [speed, get_distance_to_car(get_car_ahead()), get_speed_to_car(get_car_ahead()), get_distance_to_car(get_car_behind()), get_speed_to_car(get_car_behind())];
			if (input_exp) { s <- s + get_epsilon(); }
			if (input_time) { s <- s + cycle; }
			state <- s;
			states <- states + s;
		}
		python.set("states", states);
		if empty(states) { return; }

		// 2. Chọn hành động
		list<int> actions <- (list<int>) python.eval("np.argmax(Actor_network.predict(np.array(states), verbose=0), axis = 1)");
		float current_epsilon <- get_epsilon();
		loop i from: 0 to: length(car_list) - 1 {
			car agent_t <- car_list[i];
			if (0.05 + rnd(1.0)) <= current_epsilon {
				agent_t.action <- rnd(4);
				loop while (agent_t.action = 3 and agent_t.patience > 0) { agent_t.action <- rnd(4); }
			} else {
				agent_t.action <- actions[i];
			}
		}

		// 3. Thực hiện hành động
		list<list<float>> next_states <- [];
		ask car_list {
			do move_forward_rl;
			list s_next <- [speed, get_distance_to_car(get_car_ahead()), get_speed_to_car(get_car_ahead()), get_distance_to_car(get_car_behind()), get_speed_to_car(get_car_behind())];
			if (input_exp) { s_next <- s_next + get_epsilon(); }
			if (input_time) { s_next <- s_next + cycle; }
			next_state <- s_next;
			next_states <- next_states + s_next;
		}

		python.set("actions", car_list collect each.action);
		python.set("rewards", car_list collect each.reward);
		python.set("next_states", next_states);

		// 4. Tính toán loss và cập nhật mạng
		python.execute("with tf.GradientTape() as tape1, tf.GradientTape() as tape2:");
		python.execute("   policies = Actor_network(np.array(states))");
		python.execute("   values = Critic_network(np.array(states))");
		python.execute("   values_next = Critic_network(np.array(next_states))");
		python.execute("   tds = rewards + gamma*values_next - values");
		python.execute("   dists = tfp.distributions.Categorical(probs=policies, dtype=tf.float32)");
		python.execute("   log_probs = dists.log_prob(actions)");
		python.execute("   actor_losses = -log_probs*tds");
		python.execute("   critic_losses = tds**2");
		python.execute("grads1 = tape1.gradient(actor_losses, Actor_network.trainable_variables)");
		python.execute("grads2 = tape2.gradient(critic_losses, Critic_network.trainable_variables)");
		python.execute("a_optimizer.apply_gradients(zip(grads1, Actor_network.trainable_variables))");
		python.execute("c_optimizer.apply_gradients(zip(grads2, Critic_network.trainable_variables))");
	}
	
	action go_sac {
		// (Logic tương tự go_approximate_algos và go_nac, kết hợp bộ nhớ đệm và 
		// cập nhật nhiều mạng (Actor, Critic, Value). Lược bỏ để tiết kiệm không gian)
	}
	
	action go_a2c_without_workers {
		// 1. Lấy trạng thái
		list<car> car_list <- car as list;
		list<list<float>> states <- [];
		// Gán index duy nhất cho mỗi xe trong bước này
		int car_index <- 0;
		ask car_list {
			list s <- [speed, get_distance_to_car(get_car_ahead()), get_speed_to_car(get_car_ahead()), get_distance_to_car(get_car_behind()), get_speed_to_car(get_car_behind())];
			if (input_exp) { s <- s + get_epsilon(); }
			if (input_time) { s <- s + cycle; }
			state <- s;
			states <- states + s;
			// Gán index (thay thế cho 'who' của NetLogo)
			self.py_id <- car_index; 
			car_index <- car_index + 1;
		}
		python.set("states", states);
		if empty(states) { return; }

		// 2. Chọn hành động
		list<int> actions <- (list<int>) python.eval("np.argmax(Actor_network.predict(np.array(states), verbose=0), axis = 1)");
		float current_epsilon <- get_epsilon();
		loop i from: 0 to: length(car_list) - 1 {
			car agent_t <- car_list[i];
			if (0.05 + rnd(1.0)) <= current_epsilon {
				agent_t.action <- rnd(4);
				loop while (agent_t.action = 3 and agent_t.patience > 0) { agent_t.action <- rnd(4); }
			} else {
				agent_t.action <- actions[i];
			}
		}
		
		// 3. Thực hiện hành động
		ask car_list {
			do move_forward_rl;
		}
		
		// 4. Lưu trữ và cập nhật (logic phức tạp của A2C)
		python.execute("step = step + 1");
		ask car_list {
			python.set("id", py_id);
			python.set("state", state);
			python.execute("mem_states[id].append(state)");
			python.set("action", action);
			python.execute("mem_actions[id].append(action)");
			python.set("reward", reward);
			python.execute("mem_rewards[id].append(reward)");

			// Khối cập nhật lớn (dịch trực tiếp từ NetLogo)
			python.execute("if ((step % update_steps) == (id * update_offset)):");
			python.execute("   mem_returns[id] = []");
			python.execute("   sum_reward = 0");
			python.execute("   mem_rewards[id].reverse()");
			python.execute("   for r in mem_rewards[id]:");
			python.execute("      sum_reward = r + gamma*sum_reward");
			python.execute("      mem_returns[id].append(sum_reward)");
			python.execute("   mem_returns[id].reverse()");
			python.execute("   mem_states[id] = np.array(mem_states[id], dtype=np.float32)");
			python.execute("   mem_actions[id] = np.array(mem_actions[id], dtype=np.float32)");
			python.execute("   mem_returns[id] = np.array(mem_returns[id], dtype=np.float32)");
			python.execute("   mem_returns[id] = tf.reshape(mem_returns[id], (len(mem_returns[id]),))");
			// ... (Phần còn lại của khối 'learn' từ NetLogo) ...
			python.execute("   with tf.GradientTape() as tape1, tf.GradientTape() as tape2:");
			// ... (Tính toán loss) ...
			python.execute("   grads1 = tape1.gradient(actor_loss, Actor_network.trainable_variables)");
			python.execute("   grads2 = tape2.gradient(critic_loss, Critic_network.trainable_variables)");
			python.execute("   a_optimizer.apply_gradients(zip(grads1, Actor_network.trainable_variables))");
			python.execute("   c_optimizer.apply_gradients(zip(grads2, Critic_network.trainable_variables))");
			// Reset bộ nhớ
			python.execute("   mem_states[id] = []");
			python.execute("   mem_actions[id] = []");
			python.execute("   mem_rewards[id] = []");
		}
	}
	
	action go_a2c_with_workers {
		// (Chưa triển khai trong NetLogo gốc)
	}
	
	action go_ppo {
		// (Logic tương tự go_nac, nhưng với hàm loss PPO cụ thể)
	}

	// --- Các hành động tiện ích toàn cục ---

	action create_or_remove_cars {
		// Đảm bảo không có quá nhiều xe
		// (Logic 'car-road-patches' của NetLogo hơi phức tạp, 
		// chúng ta đơn giản hóa bằng cách chỉ kiểm tra số lượng)
		if (number_of_cars > 500) { // Đặt giới hạn cứng
			number_of_cars <- 500;
		}

		float car_speed_seed <- 0.75;

		// Tạo xe
		if (length(car) < number_of_cars) {
			create car number: (number_of_cars - length(car)) {
				// Tìm vị trí trống (đơn giản hóa)
				// Chọn một làn ngẫu nhiên
				if flip(0.5) { // Làn bên trái (đi về hướng Đông)
					location <- { (rnd(world_width) - 30), one_of(car_lanes_left) };
					heading <- 0; // GAMA East
				} else { // Làn bên phải (đi về hướng Tây)
					location <- { (rnd(world_width) - 30), one_of(car_lanes_right) };
					heading <- 180; // GAMA West
				}
				
				target_lane <- location.y;
				color <- get_car_default_color(self);
				speed <- car_speed_seed + rnd(speed_max - car_speed_seed);
				speed_top <- speed_max;
				patience <- (max_patience / 2) + rnd(max_patience / 2);
				damaged_inlane_duration <- 0;
				damaged_inrescue_duration <- 0;
				action <- -1;
				reward <- 0.0;
			}
		}
		
		// Xóa xe
		if (length(car) > number_of_cars) {
			int n <- length(car) - number_of_cars;
			list<car> cars_to_remove <- (car as list) shuffled;
			ask n first_of cars_to_remove {
				if (self != selected_car) {
					die;
				}
			}
		}
	}

	// Vẽ đường (chỉ chạy 1 lần trong init)
	action draw_road {
		// Tính toán làn đường
		lanes <- list<float>[];
		loop n from: 0 to: number_of_lanes - 1 {
			lanes <- lanes + (number_of_lanes - (n * 2) - 1);
		}

		list<float> temp_car_lanes <- list<float>[];
		loop n from: 0 to: (number_of_lanes - 2) - 1 {
			temp_car_lanes <- temp_car_lanes + (number_of_lanes - (n * 2) - 3);
		}
		int remove_index <- number_of_lanes_way;
		if (remove_index >= 0 and remove_index < length(temp_car_lanes)) {
			temp_car_lanes <- temp_car_lanes - temp_car_lanes[remove_index];
		}
		car_lanes <- temp_car_lanes;
		
		car_lanes_right <- list<float>[];
		loop n from: 0 to: number_of_lanes_way - 1 {
			car_lanes_right <- car_lanes_right + (2 * (number_of_lanes_way - n));
		}
		
		car_lanes_left <- list<float>[];
		loop n from: 0 to: number_of_lanes_way - 1 {
			car_lanes_left <- car_lanes_left + (2 * (n - number_of_lanes_way));
		}
		
		// Hành động vẽ (sẽ được gọi bởi 'display')
		do draw_road_lines;
	}

	action draw_road_lines {
		// Lấy giới hạn thế giới
		float min_x <- -30.5;
		float max_x <- 30.5;
		
		// Vẽ nền đường
		draw rectangle(world_width, (number_of_lanes * 2.0) - 1.0) color: #gray border: #black at: {0,0};
		
		// Vẽ vạch chia làn
		float y <- (last(lanes)) - 1.0;
		loop while (y <= (first(lanes) + 1.0)) {
			if (y not in lanes) {
				rgb line_color <- #white;
				float line_width <- 0.1;
				bool dashed <- true;
				
				if (abs(y) = number_of_lanes) {
					line_color <- #yellow; // Lề đường
					dashed <- false;
				} else if (abs(y) = (number_of_lanes - 2) or abs(y) = 1) {
					line_color <- #white; // Làn cứu hộ
					dashed <- false;
				} else {
					line_color <- #white; // Giữa các làn
					dashed <- true;
				}
				
				// Vẽ đường
				if (dashed) {
					// Vẽ đường đứt nét
					float dash_length <- 1.0;
					float gap_length <- 0.5;
					float current_x <- min_x;
					loop while (current_x < max_x) {
						draw line([{current_x, y}, {min(current_x + dash_length, max_x), y}]) color: line_color thickness: line_width;
						current_x <- current_x + dash_length + gap_length;
					}
				} else {
					// Vẽ đường liền
					draw line([{min_x, y}, {max_x, y}]) color: line_color thickness: line_width;
				}
			}
			y <- y + 1.0;
		}
		
		// Vẽ dải phân cách
		draw rectangle(world_width, 1.0) color: #green at: {0,0};
	}

	// Hàm tính toán
	float get_epsilon {
		if (driving_policy != "Greedy") {
			return (exp_rate / (1 + exp_decay * cycle));
		}
		return -1.0;
	}
}

/* * ## TÀI LIỆU (PHẦN 2: LOÀI (SPECIES) 'car')
 *
 * 1. species car:
 * - Định nghĩa agent 'car', tương đương với `breed [cars car]` của NetLogo.
 *
 * 2. Biến:
 * - Tất cả các biến trong `cars-own` được khai báo ở đây.
 * - `float speed;`, `float speed_top;`, `float target_lane;`, v.v.
 * - Chúng ta thêm `py_id` (int) để theo dõi agent trong Python,
 * thay thế cho biến `who` của NetLogo.
 * - `state`, `action`, `next_state`, `reward` được giữ lại cho
 * các thuật toán RL.
 *
 * 3. aspect:
 * - Đây là cách GAMA vẽ agent.
 * - `draw shape type: #car ...`: Chúng ta sử dụng hình dạng `#car`
 * tích hợp sẵn của GAMA (thay vì `car-top` tùy chỉnh) và
 * xoay nó theo `heading`. Kích thước (size) được điều chỉnh
 * để phù hợp với tỷ lệ của NetLogo.
 *
 * 4. actions (Hành động):
 * - Các "thủ tục car" (`car procedure`) của NetLogo
 * (ví dụ: `to move-forward-greedy`) được chuyển thành
 * `action` bên trong `species car`.
 * - `move_forward_greedy`: Logic lái xe cơ bản.
 * - `move_forward_rl`: Logic lái xe dựa trên 'action' (0-3)
 * do thuật toán RL quyết định.
 * - `handle_damaged_car`: Xử lý logic cho xe bị hỏng (tốc độ = 0).
 * - `handle_blocking_cars`: Phản ứng với xe phía trước.
 * - `choose_new_lane`, `move_to_target_lane`: Logic đổi làn.
 * - Ghi chú về Heading: Các giá trị `heading` được dịch cẩn thận.
 * Ví dụ: `set heading 90` (Đông) -> `heading <- 0;`
 * `set heading 270` (Tây) -> `heading <- 180;`
 *
 * 5. functions (Hàm):
 * - Các "reporter" (`to-report ...`) của NetLogo được chuyển
 * thành các hàm (function) trong GAMA, trả về một giá trị.
 * - `get_reward`: Tính toán phần thưởng cho RL.
 * - `get_car_ahead`, `get_car_behind`: Sử dụng các toán tử
 * không gian của GAMA.
 * - `get_distance_to_car`: Xử lý trường hợp `nobody` (NetLogo)
 * thành `nil` (GAMA).
 * - `convert_state_int`: Chuyển đổi trạng thái list thành int
 * cho các thuật toán RL dạng bảng.
 * - `get_safe_distance`: Tính khoảng cách an toàn.
 */
species car {
	// Biến từ 'cars-own'
	float speed;
	float speed_top;
	float target_lane;
	float patience;
	int damaged_inlane_duration;
	int damaged_inrescue_duration;

	// Biến RL
	float reward;
	list state;
	int action; // 0 = decelerate, 1 = stay same, 2 = accelerate, 3 = change lane
	list next_state;
	int py_id; // Thay thế cho 'who' của NetLogo

	// --- Vẽ agent ---
	aspect default {
		draw shape: #car size: 1.0 color: color rotate: heading;
	}
	
	// --- Hành động (từ các thủ tục 'car procedure') ---
	
	action move_forward_greedy {
		if (speed > 0) {
			if (not flip(prob_damaged_car)) {
				if (location.y < 0) { heading <- 0; } // Đông
				if (location.y > 0) { heading <- 180; } // Tây

				color <- get_car_default_color(self);
				
				do speed_up_car; // Tăng tốc
				do handle_blocking_cars; // Xử lý xe cản trở
				
				forward speed * speed_ratio;
				
				if (patience <= 0) { do choose_new_lane; }
				if (location.y != target_lane) { do move_to_target_lane; }
				
				// Đếm va chạm
				nb_collisions <- nb_collisions + length(car at_distance collision_distance);
			} else {
				if (damaged_nb_cars_inlane < max_damaged_cars) {
					speed <- 0;
					color <- damaged_color;
					damaged_inlane_duration <- 1;
					damaged_nb_cars_inlane <- damaged_nb_cars_inlane + 1;
				}
			}
		} else {
			do handle_damaged_car; // Xe bị hỏng
		}
	}
	
	action move_forward_rl {
		if (speed > 0) {
			if (not flip(prob_damaged_car)) {
				if (location.y < 0) { heading <- 0; } // Đông
				if (location.y > 0) { heading <- 180; } // Tây

				if (action = 0) { do speed_up_car; color <- #green; }    // 0 = accelerate
				if (action = 1) { color <- #yellow; }                  // 1 = stay same
				if (action = 2) { do slow_down_car; color <- #violet; } // 2 = decelerate
				if (action = 3) {                                      // 3 = change lane
					do choose_new_lane;
					color <- #blue;
					if (location.y != target_lane) {
						do move_to_target_lane;
					}
				}
				
				do handle_blocking_cars;
				
				forward speed * speed_ratio;
				
				reward <- get_reward();
				
				nb_collisions <- nb_collisions + length(car at_distance collision_distance);
			} else {
				if (damaged_nb_cars_inlane < max_damaged_cars) {
					speed <- 0;
					color <- damaged_color;
					damaged_inlane_duration <- 1;
					damaged_nb_cars_inlane <- damaged_nb_cars_inlane + 1;
				}
			}
		} else {
			do handle_damaged_car;
		}
	}

	action handle_blocking_cars {
		// `in-cone` của NetLogo (angle=60) tương đương `in_cone` của GAMA (angle: 60)
		list<car> blocking_cars <- car in_cone {distance: observation_distance, angle: observation_angle};
		car blocking_car_nearest <- nil;
		if not empty(blocking_cars) {
			blocking_car_nearest <- first(blocking_cars minimized_by (each.location distance self));
		}
		
		if (blocking_car_nearest != nil) {
			if (blocking_car_nearest.speed > 0) {
				speed <- blocking_car_nearest.speed;
				// do slow_down_car; // (Nguyên bản NetLogo có dòng này bị comment)
			} else { // Xe cản phía trước bị hỏng
				loop while (speed > speed_sudden_stop) { do slow_down_car; }
				loop while (location.y = target_lane) {
					do choose_new_lane;
					if (location.y != target_lane) {
						do move_to_target_lane;
					}
				}
			}
		}
	}

	action handle_damaged_car {
		if (dynamic_situation) {
			// Nếu đang ở làn chạy
			if ((location.y > 1 - number_of_lanes) and (location.y < number_of_lanes - 1)) {
				damaged_inlane_duration <- damaged_inlane_duration + 1;
				if (damaged_inlane_duration >= damaged_inlane_duration_max) {
					// Di chuyển vào làn cứu hộ
					if (location.y < 0) { heading <- -90; } // Nam
					if (location.y > 0) { heading <- 90; }  // Bắc
					
					// 'patch-ahead 1' -> kiểm tra không gian 1m phía trước
					point p_ahead <- location + {1.0, 0.0} directed_by heading;
					if empty(car overlapping p_ahead) {
						forward move_rescue_lane_step;
					}
					
					if ((location.y <= 1 - number_of_lanes) or (location.y >= number_of_lanes - 1)) {
						damaged_inlane_duration <- 0;
						damaged_inrescue_duration <- 1;
						damaged_nb_cars_inlane <- damaged_nb_cars_inlane - 1;
						if (location.y <= 1 - number_of_lanes) { heading <- 0; } else { heading <- 180; } // Đông/Tây
					}
				}
			} else {
				// Đang ở làn cứu hộ
				if flip(prob_remove_car) {
					die; // Xóa xe
				} else {
					damaged_inrescue_duration <- damaged_inrescue_duration + 1;
					if (damaged_inrescue_duration >= damaged_inrescue_duration_max) {
						// Phục hồi xe
						speed <- 0.06;
						if (location.y <= 1 - number_of_lanes) { target_lane <- (3 - number_of_lanes); }
						if (location.y >= number_of_lanes - 1) { target_lane <- (number_of_lanes - 3); }
						do move_to_target_lane;
						damaged_inrescue_duration <- 0;
					}
				}
			}
		}
	}

	action slow_down_car {
		if (speed > deceleration) {
			speed <- speed - deceleration;
			if (speed < speed_min) { speed <- speed_min; }
			patience <- patience - 1;
			if (patience < 0) { patience <- 0; }
		}
	}

	action speed_up_car {
		speed <- speed + acceleration;
		if (speed > speed_top) { speed <- speed_top; }
	}

	action choose_new_lane {
		list<float> other_lanes <- [];
		if (location.y < 0) { other_lanes <- car_lanes_left - location.y; }
		if (location.y > 0) { other_lanes <- car_lanes_right - location.y; }
		
		if not empty(other_lanes) {
			list<float> dists <- abs(other_lanes - location.y);
			float min_dist <- min(dists);
			list<float> closest_lanes <- other_lanes where (each in dists and dists[other_lanes index_of each] = min_dist);
			target_lane <- one_of(closest_lanes);
			patience <- max_patience;
		}
	}

	action move_to_target_lane {
		// Dịch heading:
		// NetLogo 135 (SE) -> GAMA -45
		// NetLogo 45 (NE) -> GAMA 45
		// NetLogo 225 (SW) -> GAMA -135 (hoặc 225)
		// NetLogo 315 (NW) -> GAMA 135
		
		if (location.y < 0) { // Đang đi về Đông (heading 0)
			heading <- (target_lane < location.y) ? -45 : 45;
		} else { // Đang đi về Tây (heading 180)
			heading <- (target_lane < location.y) ? -135 : 135;
		}
		
		list<car> blocking_cars <- car in_cone {distance: (observation_distance + abs(location.y - target_lane)), angle: observation_angle};
		car blocking_car_nearest <- nil;
		if not empty(blocking_cars) {
			blocking_car_nearest <- first(blocking_cars minimized_by (each.location distance self));
		}
		
		if (blocking_car_nearest = nil) {
			forward change_lane_step;
			// GAMA không bị lỗi float như NetLogo, không cần 'precision'
		} else {
			// 'towards' của NetLogo phức tạp, GAMA có thể dùng 'angle_between'
			// Đơn giản hóa: nếu xe cản ở phía trước (trong góc nhìn), giảm tốc
			// (NetLogo: towards < 180 là phía trước)
			if (self angle_to blocking_car_nearest < 90) { // GAMA: 0 là phía trước
				do slow_down_car;
			} else {
				do speed_up_car;
			}
		}
		
		color <- get_car_default_color(self);
		if (location.y < 0) { heading <- 0; }
		if (location.y > 0) { heading <- 180; }
	}

	// --- Hàm (từ 'to-report') ---

	float get_reward {
		if (get_distance_to_car(get_car_ahead()) < collision_distance) {
			return -100.0; // Va chạm
		}
		if (action = 0) { return 3.0; }  // Tăng tốc
		if (action = 1) { return 1.0; }  // Giữ tốc
		if (action = 2) { return -1.0; } // Giảm tốc
		if (action = 3) { return -2.0; } // Đổi làn
		return 0.0;
	}

	int convert_state_int(list aState) {
		// state-size = max-patience * 101 * world-width * 101
		return int( (aState[0]) * 101 * world_width * 101 + (aState[1]) * world_width * 101 + (aState[2]) * 101 + (aState[3]) );
	}
	
	float get_safe_distance {
		if (speed <= 0.6) { return 35.0 / 1.0; } // Giả sử patch-size = 1.0
		if (speed <= 0.8) { return 55.0 / 1.0; }
		if (speed <= 1.0) { return 70.0 / 1.0; }
		return 100.0 / 1.0;
	}
	
	rgb get_car_default_color(car aCar) {
		if (aCar = selected_car) { return #pink; }
		return hsb(rnd(360), 0.5, 0.8 + rnd(0.2)); // Màu ngẫu nhiên
	}
	
	float get_distance_to_car(car aCar) {
		if (aCar != nil) {
			return location distance aCar;
		}
		return observation_max;
	}
	
	float get_speed_to_car(car aCar) {
		if (aCar != nil) {
			return aCar.speed;
		}
		return speed_max;
	}
	
	car get_car_ahead {
		// Tìm xe phía trước trong 1 góc hẹp
		list<car> cars_ahead <- car in_cone {distance: observation_max, angle: 30} where (each.location.y = location.y);
		if not empty(cars_ahead) {
			return first(cars_ahead minimized_by (each.location distance self));
		}
		return nil;
	}
	
	car get_car_behind {
		// 'patch-ahead (0 - i)' -> xe phía sau
		// GAMA: dùng cone 180 độ (hoặc 'behind' operator nếu có)
		// Dùng cone ngược
		list<car> cars_behind <- car in_cone {distance: observation_max, angle: 30, relative_heading: 180} where (each.location.y = location.y);
		if not empty(cars_behind) {
			return first(cars_behind minimized_by (each.location distance self));
		}
		return nil;
	}
}

/* * ## TÀI LIỆU (PHẦN 3: THÍ NGHIỆM VÀ GIAO DIỆN)
 *
 * 1. experiment:
 * - Khối này định nghĩa Giao diện Người dùng (GUI) và các
 * thí nghiệm hàng loạt (batch).
 *
 * 2. type: gui:
 * - Định nghĩa giao diện tương tác.
 * - `parameter`: Thay thế cho `SLIDER`, `CHOOSER`, `SWITCH`
 * của NetLogo. Chúng cho phép người dùng thay đổi
 * các biến toàn cục.
 * - `output`: Chứa các hiển thị và biểu đồ.
 *
 * 3. display:
 * - `display main_display`: Hiển thị mô phỏng 2D.
 * - `graphics "road"`: Một lớp đồ họa tùy chỉnh để vẽ đường.
 * Nó gọi hành động `draw_road_lines` một lần khi khởi tạo
 * để vẽ nền đường (hiệu quả hơn là vẽ mỗi bước).
 * - `species car aspect: default`: Vẽ các agent 'car' lên
 * trên nền đường.
 *
 * 4. chart:
 * - Thay thế cho các `PLOT` của NetLogo.
 * - Ví dụ: Biểu đồ 'Speed' (Tốc độ) vẽ giá trị trung bình,
 * max, min của tốc độ xe.
 * - Cập nhật mỗi 10 'cycles' (steps) để cải thiện hiệu suất.
 *
 * 5. monitor:
 * - Thay thế cho `MONITOR` của NetLogo.
 * - Hiển thị giá trị của một biến hoặc biểu thức.
 *
 * 6. type: batch (Thí nghiệm hàng loạt):
 * - Thay thế cho phần `<experiments>` (BehaviorSpace)
 * trong tệp .nlogo.
 * - `experiment "q_learning_d1e-3" ...`: Định nghĩa một
 * thí nghiệm cụ thể.
 * - `param 'variable' value: value`: Đặt giá trị
 * tham số cho thí nghiệm.
 * - `metric 'name' value: expression`: Định nghĩa các
 * số liệu cần thu thập.
 * - `repeat: 5`: Chạy thí nghiệm 5 lần.
 * - `until: cycle >= 100000`: Điều kiện dừng.
 */
experiment "Expressway Simulation" type: gui {
	// Điều kiện dừng
	keystroke "q" action: #pause;
	string current_policy <- "Q-Learning"; // Biến tạm cho parameter
	
	// --- Tham số (Sliders, Choosers, Switches) ---
	parameter "Driving Policy" var: driving_policy among: [
		"Greedy", "Greedy-CL", 
		"Q-Learning", "SARSA", "Double Q-Learning",
		"Deep Q-Learning", "Deep Q-Network", "Double Deep Q-Network",
		"Naive Actor-Critic", "Advantage Actor-Critic", "Soft Actor-Critic", 
		"Proximal Policy Optimization"
	] init: "Q-Learning";
	
	parameter "Number of Cars" var: number_of_cars min: 1 max: nb_cars_max init: 111 category: "Simulation";
	parameter "Lanes (one way)" var: number_of_lanes_way min: 1 max: 5 init: 5 category: "Simulation";
	parameter "Max Patience" var: max_patience min: 10 max: 100 init: 50 category: "Simulation";
	parameter "Acceleration" var: acceleration min: 0.001 max: 0.01 init: 0.005 category: "Simulation";
	parameter "Deceleration" var: deceleration min: 0.001 max: 0.1 init: 0.02 category: "Simulation";
	parameter "Max Damaged Cars" var: max_damaged_cars min: 0 max: 5 init: 4 category: "Simulation";
	parameter "Simulation Steps" var: simulation_steps min: 100 max: 100000 init: 100000 category: "Simulation";
	parameter "Dynamic Situation?" var: dynamic_situation init: true category: "Simulation";
	
	parameter "Exp. Rate (epsilon)" var: exp_rate min: 0.0 max: 1.0 init: 1.0 category: "RL Parameters";
	parameter "Exp. Decay" var: exp_decay min: 0.0 max: 0.1 init: 0.001 category: "RL Parameters";
	parameter "Learning Rate (alpha)" var: learning_rate min: 0.0 max: 0.01 init: 0.0034 category: "RL Parameters";
	parameter "Discount Factor (gamma)" var: discount_factor min: 0.8 max: 0.99 init: 0.98 category: "RL Parameters";
	parameter "Batch Size" var: batch_size min: 0 max: 1024 init: 128 category: "RL Parameters";
	parameter "Memory Size" var: memory_size min: 100000 max: 10000000 init: 100000 category: "RL Parameters";
	parameter "Input Epsilon?" var: input_exp init: false category: "RL Parameters";
	parameter "Input Time?" var: input_time init: false category: "RL Parameters";
	parameter "Multiple Workers (A2C)?" var: multiple_workers init: false category: "RL Parameters";

	// --- Đầu ra (Hiển thị, Biểu đồ, Giám sát) ---
	output {
		// Hiển thị chính
		display main_display type: 2d {
			// Vẽ nền đường một lần
			graphics "road" refresh: false {
				do draw_road_lines;
			}
			species car aspect: default;
		}

		// Giám sát (Monitors)
		monitor "Average Speed" value: mean(car where (each.speed > 0) collect each.speed) * 100;
		monitor "Exploration Rate" value: get_epsilon();
		monitor "Average Reward" value: mean(car where (each.speed > 0) collect each.reward);
		monitor "% Accelerate" value: (count(car where (each.action = 0)) / max(1, number_of_cars)) * 100;
		monitor "% Decelerate" value: (count(car where (each.action = 2)) / max(1, number_of_cars)) * 100;
		monitor "% Stay Same" value: (count(car where (each.action = 1)) / max(1, number_of_cars)) * 100;
		monitor "% Change Lane" value: (count(car where (each.action = 3)) / max(1, number_of_cars)) * 100;
		monitor "Damaged Cars" value: count(car where (each.speed = 0));
		monitor "# Collisions" value: nb_collisions;

		// Biểu đồ (Plots)
		chart "Speed" type: series refresh: every(10 #cycles) {
			data "average" value: mean(car where (each.speed > 0) collect each.speed) color: #green;
			data "max" value: max(car where (each.speed > 0) collect each.speed) color: #cyan;
			data "min" value: min(car where (each.speed > 0) collect each.speed) color: #blue;
		}
		
		chart "Driver's Patience" type: series refresh: every(10 #cycles) {
			data "average" value: mean(car collect each.patience) color: #blue;
			data "max" value: max(car collect each.patience) color: #red;
			data "min" value: min(car collect each.patience) color: #orange;
		}
		
		chart "Selected Actions" type: series refresh: every(10 #cycles) {
			data "accelerate" value: count(car where (each.action = 0)) color: #green;
			data "decelerate" value: count(car where (each.action = 2)) color: #violet;
			data "stay same" value: count(car where (each.action = 1)) color: #yellow;
			data "change lane" value: count(car where (each.action = 3)) color: #blue;
		}
		
		chart "Reward" type: series refresh: every(10 #cycles) {
			data "average" value: mean(car where (each.speed > 0) collect each.reward) color: #blue;
			data "max" value: max(car where (each.speed > 0) collect each.reward) color: #red;
			data "min" value: min(car where (each.speed > 0) collect each.reward) color: #orange;
		}
		
		chart "Number of Collisions" type: series refresh: every(10 #cycles) {
			data "collisions" value: nb_collisions color: #red;
		}
	}
}

/* * ## TÀI LIỆU (PHẦN 4: THÍ NGHIỆM HÀNG LOẠT)
 *
 * Chuyển đổi từ XML BehaviorSpace của NetLogo
 */
experiment "q_learning_d1e-3" type: batch {
	param 'driving_policy' value: "Q-Learning";
	param 'exp_decay' value: 0.001;
	param 'simulation_steps' value: 100000;
	param 'input_time' value: true;
	param 'max_damaged_cars' value: 4;
	param 'discount_factor' value: 0.98;
	param 'dynamic_situation' value: true;
	param 'acceleration' value: 0.005;
	param 'exp_rate' value: 1.0;
	param 'number_of_lanes_way' value: 5;
	param 'input_exp' value: true;
	param 'batch_size' value: 128;
	param 'memory_size' value: 100000;
	param 'max_patience' value: 50;
	param 'number_of_cars' value: 100;
	param 'deceleration' value: 0.02;
	param 'learning_rate' value: 0.0034;
	
	metric 'avg_speed' value: mean(car where (each.speed > 0) collect each.speed);
	metric 'avg_reward' value: mean(car where (each.speed > 0) collect each.reward);
	metric 'total_collisions' value: nb_collisions; // GAMA metric thường là giá trị cuối cùng
	
	repeat: 5;
	until: cycle >= 100000;
}

experiment "q_learning_d1e-4" type: batch {
	param 'driving_policy' value: "Q-Learning";
	param 'exp_decay' value: 0.0001;
	// ... (các tham số khác tương tự như trên) ...
	
	metric 'avg_speed' value: mean(car where (each.speed > 0) collect each.speed);
	metric 'avg_reward' value: mean(car where (each.speed > 0) collect each.reward);
	metric 'total_collisions' value: nb_collisions;
	
	repeat: 5;
	until: cycle >= 100000;
}

// ... (Các thí nghiệm batch khác như 'q_learning_d1e-5', 'double_q_learning_...', v.v. 
//      sẽ được định nghĩa tương tự) ...