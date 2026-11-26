model Expressways

global {
	// Globals from NetLogo (giữ nguyên)
	agent selected_car;
	int nb_cars_max;
	int number_of_lanes;
	list<int> lanes;
	list<int> car_lanes;
	list<int> car_lanes_left;
	list<int> car_lanes_right;
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
	int hidden_layer_size;
	list<float> state_env;
	int ac_update_steps;
	
	// Tham số (giữ nguyên)
	float discount_factor;
	float learning_rate;
	float exp_rate;
	float exp_decay;
	bool input_exp;
	bool input_time;
	int memory_size;
	int batch_size ;
	int simulation_steps ;
	int max_damaged_cars ;
	bool dynamic_situation ;
	float acceleration ;
	float deceleration ;
	int number_of_lanes_way ;
	float clip_param ;
	bool save_experience ;
	bool multiple_workers  ;
	int number_of_cars ;
	int max_patience;
	string driving_policy ;

	// Cho tabular RL: Q-table là list<list<float>> đa chiều
	list<list<float>> Q; // Cho SARSA/Q-Learning
	list<list<float>> QA; // Cho Double Q-Learning
	list<list<float>> QB; // Cho Double Q-Learning
	int state_size;
	int _action <- 1;
	int action_size <- 4; // 0=decel, 1=stay, 2=accel, 3=change lane
	
	init {
		// Setup giữ nguyên, loại bỏ Python
		number_of_lanes <- number_of_lanes_way * 2 + 3;
		nb_cars_max <- int(number_of_lanes_way * 1.5 * world.shape.width * 0.25);
		speed_max <- 1.0;
		speed_min <- 0.0;
		speed_sudden_stop <- 0.05;
		speed_ratio <- 0.35;
		collision_distance <- 1.0;
		damaged_color <- #red;
		damaged_inlane_duration_max <- 1800;
		damaged_inrescue_duration_max <- 2700;
		damaged_nb_cars_inlane <- 0;
		change_lane_step <- 0.08;
		move_rescue_lane_step <- change_lane_step * 0.1;
		prob_damaged_car <- 0.00002;
		prob_add_car <- 0.005;
		prob_remove_car <- 0.00005;
		observation_max <- world.shape.width / 2;
		observation_distance <- 2.5;
		observation_angle <- 60;
		hidden_layer_size <- 36;
		ac_update_steps <- 2000;

		do draw_road;
		do create_or_remove_cars;

		selected_car <- one_of(cars);
		ask selected_car { color <- #pink; }

		if (driving_policy = "Greedy" or driving_policy = "Greedy-CL") {
			// Greedy
		} else if (driving_policy in ["SARSA", "Q-Learning", "Double Q-Learning"]) {
			do setup_tabular_algos;
		} else {
			write "Deep RL not implemented in pure GAML. Use custom Java with DL4J." color: #red;
			// Skeleton cho deep: Xem Java code dưới
		}
	}

	reflex halt when: cycle >= simulation_steps {
		write timer;
		do halt;
	}

	reflex main_loop {
		if dynamic_situation {
			if (rnd(1.0) <= prob_add_car and length(cars) < nb_cars_max) {
				number_of_cars <- number_of_cars + 1;
			}
		}

		do create_or_remove_cars;
		nb_collisions <- 0;

		if (driving_policy = "Greedy" or driving_policy = "Greedy-CL") {
			ask cars { do move_forward_greedy; }
		}

		if (driving_policy = "SARSA" or driving_policy = "Q-Learning") {
			do go_sarsa_qlearning;
		}

		if (driving_policy = "Double Q-Learning") {
			do go_double_ql;
		}

		// Deep algos: Not implemented, placeholder
		if (driving_policy in ["Deep Q-Learning", "Deep Q-Network", "Double Deep Q-Network", "Naive Actor-Critic", "Advantage Actor-Critic", "Soft Actor-Critic", "Proximal Policy Optimization"]) {
			ask cars { do move_forward_greedy; } // Fallback to greedy
			write "Using fallback greedy for deep policy.";
		}
	}
	
	// Rewrite setup_tabular_algos without Python
	action setup_tabular_algos {
		state_env <- [ patience, round(100 * speed), round(get_distance_to_car(get_car_ahead)), round(100 * get_speed_to_car(get_car_ahead)) ];
		//state_env <- [ {patience}, {round(100 * speed)}, {round(get_distance_to_car(get_car_ahead))}, {round(100 * get_speed_to_car(get_car_ahead))} ];
		state_size <- (max_patience + 1) * 101 * world.shape.width * 101;
		if (driving_policy = "SARSA" or driving_policy = "Q-Learning") {
			Q <- list_with(state_size, list_with(action_size, 0.0)); // Q-table zeros
		}
		if driving_policy = "Double Q-Learning" {
			QA <- list_with(state_size, list_with(action_size, 0.0));
			QB <- list_with(state_size, list_with(action_size, 0.0));
		}
	}
	
	// Rewrite go_sarsa_qlearning
	action go_sarsa_qlearning {
		ask cars {
			if speed > 0 {
				state <- map(each, state_env);
				int state_int <- convert_state_int(state);
				float epsilon <- get_epsilon();
				if (0.05 + rnd(1.0) < epsilon) {
					_action <- rnd(3);
					loop while: (_action = 3 and patience > 0) { _action <- rnd(3); }
				} else {
					_action <- index_of(Q[state_int], max(Q[state_int])); // argmax
				}
				do move_forward_rl;
				next_state <- map(each, state_env);
				int next_state_int <- convert_state_int(next_state);
				
				// Update Q
				if driving_policy = "SARSA" {
					int next_action <- index_of(Q[next_state_int], max(Q[next_state_int]));
					if (0.05 + rnd(1.0) < epsilon) {
						next_action <- rnd(3);
						loop while: (next_action = 3 and patience > 0) { next_action <- rnd(3); }
					}
					Q[state_int][_action] <- Q[state_int][_action] + learning_rate * (reward + discount_factor * Q[next_state_int][next_action] - Q[state_int][_action]);
				}
				if driving_policy = "Q-Learning" {
					Q[state_int][_action] <- Q[state_int][_action] + learning_rate * (reward + discount_factor * max(Q[next_state_int]) - Q[state_int][_action]);
				}
			} else {
				do handle_damaged_car;
			}
		}
	}
	
	// Tương tự cho go_double_ql
	action go_double_ql {
		ask cars {
			if speed > 0 {
				state <- map(each, state_env);
				int state_int <- convert_state_int(state);
				float epsilon <- get_epsilon();
				if (0.05 + rnd(1.0) < epsilon) {
					_action <- rnd(3);
					loop while: (_action = 3 and patience > 0) { _action <- rnd(3); }
				} else {
					list<float> avg_q <- [];
					loop i from: 0 to action_size - 1 {
						add (QA[state_int][i] + QB[state_int][i]) / 2 to: avg_q;
					}
					_action <- index_of(avg_q, max(avg_q));
				}
				do move_forward_rl;
				next_state <- map(each, state_env);
				int next_state_int <- convert_state_int(next_state);
				
				// Update QA or QB
				if rnd(1.0) < 0.5 {
					int next_action <- index_of(QA[next_state_int], max(QA[next_state_int]));
					QA[state_int][_action] <- QA[state_int][_action] + learning_rate * (reward + discount_factor * QB[next_state_int][next_action] - QA[state_int][_action]);
				} else {
					int next_action <- index_of(QB[next_state_int], max(QB[next_state_int]));
					QB[state_int][_action] <- QB[state_int][_action] + learning_rate * (reward + discount_factor * QA[next_state_int][next_action] - QB[state_int][_action]);
				}
			} else {
				do handle_damaged_car;
			}
		}
	}
	
	// Các action khác giữ nguyên (draw_road, create_or_remove_cars, move_forward_greedy, move_forward_rl, etc.)
	// ... (copy từ file gốc, loại bỏ Python)
}

grid cell width: 100 height: 20 neighbors: 4;

species cars skills: [moving] {
	// Giữ nguyên attributes
}

experiment q_learning_d1e_3 type: batch repeat: 5 until: (cycle >= 100000) {
	parameter 'input_time?' var: input_time <- true;
	parameter 'exp_decay' var: exp_decay <- 0.001;
	parameter 'simulation_steps' var: simulation_steps <- 100000;
	parameter 'max_damaged_cars' var: max_damaged_cars <- 4;
	parameter 'discount_factor' var: discount_factor <- 0.98;
	parameter 'dynamic_situation' var: dynamic_situation <- true;
	parameter 'acceleration' var: acceleration <- 0.005;
	parameter 'exp_rate' var: exp_rate <- 1;
	parameter 'number_of_lanes_way' var: number_of_lanes_way <- 5;
	parameter 'clip_param' var: clip_param <- 0.2;
	parameter 'input_exp' var: input_exp <- true;
	parameter 'save_experience' var: save_experience <- false;
	parameter 'batch_size' var: batch_size <- 128;
	parameter 'driving_policy' var: driving_policy <- "Q-Learning";
	parameter 'memory_size' var: memory_size <- 100000;
	parameter 'max_patience' var: max_patience <- 50;
	parameter 'multiple_workers' var: multiple_workers <- false;
	parameter 'number_of_cars' var: number_of_cars <- 100;
	parameter 'deceleration' var: deceleration <- 0.02;
	parameter 'learning_rate' var: learning_rate <- 0.0034;
	reflex save_results {
		save [mean([speed] of (cars where (each.speed > 0))), mean([reward] of (cars where (each.speed > 0))), nb_collisions, timer] to: "results_q_learning_d1e_3.csv" type: csv rewrite: false;
	}
}

experiment q_learning_d1e_4 type: batch repeat: 5 until: (cycle >= 100000) {
	parameter 'input_time?' var: input_time <- true;
	parameter 'exp_decay' var: exp_decay <- 1.0E-4;
	parameter 'simulation_steps' var: simulation_steps <- 100000;
	parameter 'max_damaged_cars' var: max_damaged_cars <- 4;
	parameter 'discount_factor' var: discount_factor <- 0.98;
	parameter 'dynamic_situation' var: dynamic_situation <- true;
	parameter 'acceleration' var: acceleration <- 0.005;
	parameter 'exp_rate' var: exp_rate <- 1;
	parameter 'number_of_lanes_way' var: number_of_lanes_way <- 5;
	parameter 'clip_param' var: clip_param <- 0.2;
	parameter 'input_exp' var: input_exp <- true;
	parameter 'save_experience' var: save_experience <- false;
	parameter 'batch_size' var: batch_size <- 128;
	parameter 'driving_policy' var: driving_policy <- "Q-Learning";
	parameter 'memory_size' var: memory_size <- 100000;
	parameter 'max_patience' var: max_patience <- 50;
	parameter 'multiple_workers' var: multiple_workers <- false;
	parameter 'number_of_cars' var: number_of_cars <- 100;
	parameter 'deceleration' var: deceleration <- 0.02;
	parameter 'learning_rate' var: learning_rate <- 0.0034;
	reflex save_results {
		save [mean([speed] of (cars where (each.speed > 0))), mean([reward] of (cars where (each.speed > 0))), nb_collisions, timer] to: "results_q_learning_d1e_4.csv" type: csv rewrite: false;
	}
}

experiment q_learning_d1e_5 type: batch repeat: 5 until: (cycle >= 100000) {
	parameter 'input_time?' var: input_time <- true;
	parameter 'exp_decay' var: exp_decay <- 1.0E-5;
	parameter 'simulation_steps' var: simulation_steps <- 100000;
	parameter 'max_damaged_cars' var: max_damaged_cars <- 4;
	parameter 'discount_factor' var: discount_factor <- 0.98;
	parameter 'dynamic_situation' var: dynamic_situation <- true;
	parameter 'acceleration' var: acceleration <- 0.005;
	parameter 'exp_rate' var: exp_rate <- 1;
	parameter 'number_of_lanes_way' var: number_of_lanes_way <- 5;
	parameter 'clip_param' var: clip_param <- 0.2;
	parameter 'input_exp' var: input_exp <- true;
	parameter 'save_experience' var: save_experience <- false;
	parameter 'batch_size' var: batch_size <- 128;
	parameter 'driving_policy' var: driving_policy <- "Q-Learning";
	parameter 'memory_size' var: memory_size <- 100000;
	parameter 'max_patience' var: max_patience <- 50;
	parameter 'multiple_workers' var: multiple_workers <- false;
	parameter 'number_of_cars' var: number_of_cars <- 100;
	parameter 'deceleration' var: deceleration <- 0.02;
	parameter 'learning_rate' var: learning_rate <- 0.0034;
	reflex save_results {
		save [mean([speed] of (cars where (each.speed > 0))), mean([reward] of (cars where (each.speed > 0))), nb_collisions, timer] to: "results_q_learning_d1e_5.csv" type: csv rewrite: false;
	}
}

experiment q_learning_d0 type: batch repeat: 5 until: (cycle >= 100000) {
	parameter 'input_time?' var: input_time <- true;
	parameter 'exp_decay' var: exp_decay <- 0;
	parameter 'simulation_steps' var: simulation_steps <- 100000;
	parameter 'max_damaged_cars' var: max_damaged_cars <- 4;
	parameter 'discount_factor' var: discount_factor <- 0.98;
	parameter 'dynamic_situation' var: dynamic_situation <- true;
	parameter 'acceleration' var: acceleration <- 0.005;
	parameter 'exp_rate' var: exp_rate <- 1;
	parameter 'number_of_lanes_way' var: number_of_lanes_way <- 5;
	parameter 'clip_param' var: clip_param <- 0.2;
	parameter 'input_exp' var: input_exp <- true;
	parameter 'save_experience' var: save_experience <- false;
	parameter 'batch_size' var: batch_size <- 128;
	parameter 'driving_policy' var: driving_policy <- "Q-Learning";
	parameter 'memory_size' var: memory_size <- 100000;
	parameter 'max_patience' var: max_patience <- 50;
	parameter 'multiple_workers' var: multiple_workers <- false;
	parameter 'number_of_cars' var: number_of_cars <- 100;
	parameter 'deceleration' var: deceleration <- 0.02;
	parameter 'learning_rate' var: learning_rate <- 0.0034;
	reflex save_results {
		save [mean([speed] of (cars where (each.speed > 0))), mean([reward] of (cars where (each.speed > 0))), nb_collisions, timer] to: "results_q_learning_d0.csv" type: csv rewrite: false;
	}
}

experiment q_learning_d5e_5 type: batch repeat: 5 until: (cycle >= 100000) {
	parameter 'input_time?' var: input_time <- true;
	parameter 'exp_decay' var: exp_decay <- 5.0E-5;
	parameter 'simulation_steps' var: simulation_steps <- 100000;
	parameter 'max_damaged_cars' var: max_damaged_cars <- 4;
	parameter 'discount_factor' var: discount_factor <- 0.98;
	parameter 'dynamic_situation' var: dynamic_situation <- true;
	parameter 'acceleration' var: acceleration <- 0.005;
	parameter 'exp_rate' var: exp_rate <- 1;
	parameter 'number_of_lanes_way' var: number_of_lanes_way <- 5;
	parameter 'clip_param' var: clip_param <- 0.2;
	parameter 'input_exp' var: input_exp <- true;
	parameter 'save_experience' var: save_experience <- false;
	parameter 'batch_size' var: batch_size <- 128;
	parameter 'driving_policy' var: driving_policy <- "Q-Learning";
	parameter 'memory_size' var: memory_size <- 100000;
	parameter 'max_patience' var: max_patience <- 50;
	parameter 'multiple_workers' var: multiple_workers <- false;
	parameter 'number_of_cars' var: number_of_cars <- 100;
	parameter 'deceleration' var: deceleration <- 0.02;
	parameter 'learning_rate' var: learning_rate <- 0.0034;
	reflex save_results {
		save [mean([speed] of (cars where (each.speed > 0))), mean([reward] of (cars where (each.speed > 0))), nb_collisions, timer] to: "results_q_learning_d5e_5.csv" type: csv rewrite: false;
	}
}

experiment q_learning_d3_33e_5 type: batch repeat: 5 until: (cycle >= 100000) {
	parameter 'input_time?' var: input_time <- true;
	parameter 'exp_decay' var: exp_decay <- 3.333333E-5;
	parameter 'simulation_steps' var: simulation_steps <- 100000;
	parameter 'max_damaged_cars' var: max_damaged_cars <- 4;
	parameter 'discount_factor' var: discount_factor <- 0.98;
	parameter 'dynamic_situation' var: dynamic_situation <- true;
	parameter 'acceleration' var: acceleration <- 0.005;
	parameter 'exp_rate' var: exp_rate <- 1;
	parameter 'number_of_lanes_way' var: number_of_lanes_way <- 5;
	parameter 'clip_param' var: clip_param <- 0.2;
	parameter 'input_exp' var: input_exp <- true;
	parameter 'save_experience' var: save_experience <- false;
	parameter 'batch_size' var: batch_size <- 128;
	parameter 'driving_policy' var: driving_policy <- "Q-Learning";
	parameter 'memory_size' var: memory_size <- 100000;
	parameter 'max_patience' var: max_patience <- 50;
	parameter 'multiple_workers' var: multiple_workers <- false;
	parameter 'number_of_cars' var: number_of_cars <- 100;
	parameter 'deceleration' var: deceleration <- 0.02;
	parameter 'learning_rate' var: learning_rate <- 0.0034;
	reflex save_results {
		save [mean([speed] of (cars where (each.speed > 0))), mean([reward] of (cars where (each.speed > 0))), nb_collisions, timer] to: "results_q_learning_d3_33e_5.csv" type: csv rewrite: false;
	}
}

experiment q_learning_d2_5e_5 type: batch repeat: 5 until: (cycle >= 100000) {
	parameter 'input_time?' var: input_time <- true;
	parameter 'exp_decay' var: exp_decay <- 2.5E-5;
	parameter 'simulation_steps' var: simulation_steps <- 100000;
	parameter 'max_damaged_cars' var: max_damaged_cars <- 4;
	parameter 'discount_factor' var: discount_factor <- 0.98;
	parameter 'dynamic_situation' var: dynamic_situation <- true;
	parameter 'acceleration' var: acceleration <- 0.005;
	parameter 'exp_rate' var: exp_rate <- 1;
	parameter 'number_of_lanes_way' var: number_of_lanes_way <- 5;
	parameter 'clip_param' var: clip_param <- 0.2;
	parameter 'input_exp' var: input_exp <- true;
	parameter 'save_experience' var: save_experience <- false;
	parameter 'batch_size' var: batch_size <- 128;
	parameter 'driving_policy' var: driving_policy <- "Q-Learning";
	parameter 'memory_size' var: memory_size <- 100000;
	parameter 'max_patience' var: max_patience <- 50;
	parameter 'multiple_workers' var: multiple_workers <- false;
	parameter 'number_of_cars' var: number_of_cars <- 100;
	parameter 'deceleration' var: deceleration <- 0.02;
	parameter 'learning_rate' var: learning_rate <- 0.0034;
	reflex save_results {
		save [mean([speed] of (cars where (each.speed > 0))), mean([reward] of (cars where (each.speed > 0))), nb_collisions, timer] to: "results_q_learning_d2_5e_5.csv" type: csv rewrite: false;
	}
}

experiment q_learning_d2_0e_5 type: batch repeat: 5 until: (cycle >= 100000) {
	parameter 'input_time?' var: input_time <- true;
	parameter 'exp_decay' var: exp_decay <- 2.0E-5;
	parameter 'simulation_steps' var: simulation_steps <- 100000;
	parameter 'max_damaged_cars' var: max_damaged_cars <- 4;
	parameter 'discount_factor' var: discount_factor <- 0.98;
	parameter 'dynamic_situation' var: dynamic_situation <- true;
	parameter 'acceleration' var: acceleration <- 0.005;
	parameter 'exp_rate' var: exp_rate <- 1;
	parameter 'number_of_lanes_way' var: number_of_lanes_way <- 5;
	parameter 'clip_param' var: clip_param <- 0.2;
	parameter 'input_exp' var: input_exp <- true;
	parameter 'save_experience' var: save_experience <- false;
	parameter 'batch_size' var: batch_size <- 128;
	parameter 'driving_policy' var: driving_policy <- "Q-Learning";
	parameter 'memory_size' var: memory_size <- 100000;
	parameter 'max_patience' var: max_patience <- 50;
	parameter 'multiple_workers' var: multiple_workers <- false;
	parameter 'number_of_cars' var: number_of_cars <- 100;
	parameter 'deceleration' var: deceleration <- 0.02;
	parameter 'learning_rate' var: learning_rate <- 0.0034;
	reflex save_results {
		save [mean([speed] of (cars where (each.speed > 0))), mean([reward] of (cars where (each.speed > 0))), nb_collisions, timer] to: "results_q_learning_d2_0e_5.csv" type: csv rewrite: false;
	}
}

experiment q_learning_d1_67e_5 type: batch repeat: 5 until: (cycle >= 100000) {
	parameter 'input_time?' var: input_time <- true;
	parameter 'exp_decay' var: exp_decay <- 1.666667E-5;
	parameter 'simulation_steps' var: simulation_steps <- 100000;
	parameter 'max_damaged_cars' var: max_damaged_cars <- 4;
	parameter 'discount_factor' var: discount_factor <- 0.98;
	parameter 'dynamic_situation' var: dynamic_situation <- true;
	parameter 'acceleration' var: acceleration <- 0.005;
	parameter 'exp_rate' var: exp_rate <- 1;
	parameter 'number_of_lanes_way' var: number_of_lanes_way <- 5;
	parameter 'clip_param' var: clip_param <- 0.2;
	parameter 'input_exp' var: input_exp <- true;
	parameter 'save_experience' var: save_experience <- false;
	parameter 'batch_size' var: batch_size <- 128;
	parameter 'driving_policy' var: driving_policy <- "Q-Learning";
	parameter 'memory_size' var: memory_size <- 100000;
	parameter 'max_patience' var: max_patience <- 50;
	parameter 'multiple_workers' var: multiple_workers <- false;
	parameter 'number_of_cars' var: number_of_cars <- 100;
	parameter 'deceleration' var: deceleration <- 0.02;
	parameter 'learning_rate' var: learning_rate <- 0.0034;
	reflex save_results {
		save [mean([speed] of (cars where (each.speed > 0))), mean([reward] of (cars where (each.speed > 0))), nb_collisions, timer] to: "results_q_learning_d1_67e_5.csv" type: csv rewrite: false;
	}
}

experiment q_learning_d1_43e_5 type: batch repeat: 5 until: (cycle >= 100000) {
	parameter 'input_time?' var: input_time <- true;
	parameter 'exp_decay' var: exp_decay <- 1.433333E-5;
	parameter 'simulation_steps' var: simulation_steps <- 100000;
	parameter 'max_damaged_cars' var: max_damaged_cars <- 4;
	parameter 'discount_factor' var: discount_factor <- 0.98;
	parameter 'dynamic_situation' var: dynamic_situation <- true;
	parameter 'acceleration' var: acceleration <- 0.005;
	parameter 'exp_rate' var: exp_rate <- 1;
	parameter 'number_of_lanes_way' var: number_of_lanes_way <- 5;
	parameter 'clip_param' var: clip_param <- 0.2;
	parameter 'input_exp' var: input_exp <- true;
	parameter 'save_experience' var: save_experience <- false;
	parameter 'batch_size' var: batch_size <- 128;
	parameter 'driving_policy' var: driving_policy <- "Q-Learning";
	parameter 'memory_size' var: memory_size <- 100000;
	parameter 'max_patience' var: max_patience <- 50;
	parameter 'multiple_workers' var: multiple_workers <- false;
	parameter 'number_of_cars' var: number_of_cars <- 100;
	parameter 'deceleration' var: deceleration <- 0.02;
	parameter 'learning_rate' var: learning_rate <- 0.0034;
	reflex save_results {
		save [mean([speed] of (cars where (each.speed > 0))), mean([reward] of (cars where (each.speed > 0))), nb_collisions, timer] to: "results_q_learning_d1_43e_5.csv" type: csv rewrite: false;
	}
}

experiment q_learning_d1_25e_5 type: batch repeat: 5 until: (cycle >= 100000) {
	parameter 'input_time?' var: input_time <- true;
	parameter 'exp_decay' var: exp_decay <- 1.25E-5;
	parameter 'simulation_steps' var: simulation_steps <- 100000;
	parameter 'max_damaged_cars' var: max_damaged_cars <- 4;
	parameter 'discount_factor' var: discount_factor <- 0.98;
	parameter 'dynamic_situation' var: dynamic_situation <- true;
	parameter 'acceleration' var: acceleration <- 0.005;
	parameter 'exp_rate' var: exp_rate <- 1;
	parameter 'number_of_lanes_way' var: number_of_lanes_way <- 5;
	parameter 'clip_param' var: clip_param <- 0.2;
	parameter 'input_exp' var: input_exp <- true;
	parameter 'save_experience' var: save_experience <- false;
	parameter 'batch_size' var: batch_size <- 128;
	parameter 'driving_policy' var: driving_policy <- "Q-Learning";
	parameter 'memory_size' var: memory_size <- 100000;
	parameter 'max_patience' var: max_patience <- 50;
	parameter 'multiple_workers' var: multiple_workers <- false;
	parameter 'number_of_cars' var: number_of_cars <- 100;
	parameter 'deceleration' var: deceleration <- 0.02;
	parameter 'learning_rate' var: learning_rate <- 0.0034;
	reflex save_results {
		save [mean([speed] of (cars where (each.speed > 0))), mean([reward] of (cars where (each.speed > 0))), nb_collisions, timer] to: "results_q_learning_d1_25e_5.csv" type: csv rewrite: false;
	}
}

experiment q_learning_d1_11e_5 type: batch repeat: 5 until: (cycle >= 100000) {
	parameter 'input_time?' var: input_time <- true;
	parameter 'exp_decay' var: exp_decay <- 1.111111E-5;
	parameter 'simulation_steps' var: simulation_steps <- 100000;
	parameter 'max_damaged_cars' var: max_damaged_cars <- 4;
	parameter 'discount_factor' var: discount_factor <- 0.98;
	parameter 'dynamic_situation' var: dynamic_situation <- true;
	parameter 'acceleration' var: acceleration <- 0.005;
	parameter 'exp_rate' var: exp_rate <- 1;
	parameter 'number_of_lanes_way' var: number_of_lanes_way <- 5;
	parameter 'clip_param' var: clip_param <- 0.2;
	parameter 'input_exp' var: input_exp <- true;
	parameter 'save_experience' var: save_experience <- false;
	parameter 'batch_size' var: batch_size <- 128;
	parameter 'driving_policy' var: driving_policy <- "Q-Learning";
	parameter 'memory_size' var: memory_size <- 100000;
	parameter 'max_patience' var: max_patience <- 50;
	parameter 'multiple_workers' var: multiple_workers <- false;
	parameter 'number_of_cars' var: number_of_cars <- 100;
	parameter 'deceleration' var: deceleration <- 0.02;
	parameter 'learning_rate' var: learning_rate <- 0.0034;
	reflex save_results {
		save [mean([speed] of (cars where (each.speed > 0))), mean([reward] of (cars where (each.speed > 0))), nb_collisions, timer] to: "results_q_learning_d1_11e_5.csv" type: csv rewrite: false;
	}
}

experiment double_q_learning_d1e_3 type: batch repeat: 5 until: (cycle >= 100000) {
	parameter 'input_time?' var: input_time <- true;
	parameter 'exp_decay' var: exp_decay <- 0.001;
	parameter 'simulation_steps' var: simulation_steps <- 100000;
	parameter 'max_damaged_cars' var: max_damaged_cars <- 4;
	parameter 'discount_factor' var: discount_factor <- 0.98;
	parameter 'dynamic_situation' var: dynamic_situation <- true;
	parameter 'acceleration' var: acceleration <- 0.005;
	parameter 'exp_rate' var: exp_rate <- 1;
	parameter 'number_of_lanes_way' var: number_of_lanes_way <- 5;
	parameter 'clip_param' var: clip_param <- 0.2;
	parameter 'input_exp' var: input_exp <- true;
	parameter 'save_experience' var: save_experience <- false;
	parameter 'batch_size' var: batch_size <- 128;
	parameter 'driving_policy' var: driving_policy <- "Double Q-Learning";
	parameter 'memory_size' var: memory_size <- 100000;
	parameter 'max_patience' var: max_patience <- 50;
	parameter 'multiple_workers' var: multiple_workers <- false;
	parameter 'number_of_cars' var: number_of_cars <- 100;
	parameter 'deceleration' var: deceleration <- 0.02;
	parameter 'learning_rate' var: learning_rate <- 0.0034;
	reflex save_results {
		save [mean([speed] of (cars where (each.speed > 0))), mean([reward] of (cars where (each.speed > 0))), nb_collisions, timer] to: "results_double_q_learning_d1e_3.csv" type: csv rewrite: false;
	}
}

experiment double_q_learning_d1e_4 type: batch repeat: 5 until: (cycle >= 100000) {
	parameter 'input_time?' var: input_time <- true;
	parameter 'exp_decay' var: exp_decay <- 1.0E-4;
	parameter 'simulation_steps' var: simulation_steps <- 100000;
	parameter 'max_damaged_cars' var: max_damaged_cars <- 4;
	parameter 'discount_factor' var: discount_factor <- 0.98;
	parameter 'dynamic_situation' var: dynamic_situation <- true;
	parameter 'acceleration' var: acceleration <- 0.005;
	parameter 'exp_rate' var: exp_rate <- 1;
	parameter 'number_of_lanes_way' var: number_of_lanes_way <- 5;
	parameter 'clip_param' var: clip_param <- 0.2;
	parameter 'input_exp' var: input_exp <- true;
	parameter 'save_experience' var: save_experience <- false;
	parameter 'batch_size' var: batch_size <- 128;
	parameter 'driving_policy' var: driving_policy <- "Double Q-Learning";
	parameter 'memory_size' var: memory_size <- 100000;
	parameter 'max_patience' var: max_patience <- 50;
	parameter 'multiple_workers' var: multiple_workers <- false;
	parameter 'number_of_cars' var: number_of_cars <- 100;
	parameter 'deceleration' var: deceleration <- 0.02;
	parameter 'learning_rate' var: learning_rate <- 0.0034;
	reflex save_results {
		save [mean([speed] of (cars where (each.speed > 0))), mean([reward] of (cars where (each.speed > 0))), nb_collisions, timer] to: "results_double_q_learning_d1e_4.csv" type: csv rewrite: false;
	}
}

experiment double_q_learning_d1e_5 type: batch repeat: 5 until: (cycle >= 100000) {
	parameter 'input_time?' var: input_time <- true;
	parameter 'exp_decay' var: exp_decay <- 1.0E-5;
	parameter 'simulation_steps' var: simulation_steps <- 100000;
	parameter 'max_damaged_cars' var: max_damaged_cars <- 4;
	parameter 'discount_factor' var: discount_factor <- 0.98;
	parameter 'dynamic_situation' var: dynamic_situation <- true;
	parameter 'acceleration' var: acceleration <- 0.005;
	parameter 'exp_rate' var: exp_rate <- 1;
	parameter 'number_of_lanes_way' var: number_of_lanes_way <- 5;
	parameter 'clip_param' var: clip_param <- 0.2;
	parameter 'input_exp' var: input_exp <- true;
	parameter 'save_experience' var: save_experience <- false;
	parameter 'batch_size' var: batch_size <- 128;
	parameter 'driving_policy' var: driving_policy <- "Double Q-Learning";
	parameter 'memory_size' var: memory_size <- 100000;
	parameter 'max_patience' var: max_patience <- 50;
	parameter 'multiple_workers' var: multiple_workers <- false;
	parameter 'number_of_cars' var: number_of_cars <- 100;
	parameter 'deceleration' var: deceleration <- 0.02;
	parameter 'learning_rate' var: learning_rate <- 0.0034;
	reflex save_results {
		save [mean([speed] of (cars where (each.speed > 0))), mean([reward] of (cars where (each.speed > 0))), nb_collisions, timer] to: "results_double_q_learning_d1e_5.csv" type: csv rewrite: false;
	}
}

experiment double_q_learning_d0 type: batch repeat: 5 until: (cycle >= 100000) {
	parameter 'input_time?' var: input_time <- true;
	parameter 'exp_decay' var: exp_decay <- 0;
	parameter 'simulation_steps' var: simulation_steps <- 100000;
	parameter 'max_damaged_cars' var: max_damaged_cars <- 4;
	parameter 'discount_factor' var: discount_factor <- 0.98;
	parameter 'dynamic_situation' var: dynamic_situation <- true;
	parameter 'acceleration' var: acceleration <- 0.005;
	parameter 'exp_rate' var: exp_rate <- 1;
	parameter 'number_of_lanes_way' var: number_of_lanes_way <- 5;
	parameter 'clip_param' var: clip_param <- 0.2;
	parameter 'input_exp' var: input_exp <- true;
	parameter 'save_experience' var: save_experience <- false;
	parameter 'batch_size' var: batch_size <- 128;
	parameter 'driving_policy' var: driving_policy <- "Double Q-Learning";
	parameter 'memory_size' var: memory_size <- 100000;
	parameter 'max_patience' var: max_patience <- 50;
	parameter 'multiple_workers' var: multiple_workers <- false;
	parameter 'number_of_cars' var: number_of_cars <- 100;
	parameter 'deceleration' var: deceleration <- 0.02;
	parameter 'learning_rate' var: learning_rate <- 0.0034;
	reflex save_results {
		save [mean([speed] of (cars where (each.speed > 0))), mean([reward] of (cars where (each.speed > 0))), nb_collisions, timer] to: "results_double_q_learning_d0.csv" type: csv rewrite: false;
	}
}

experiment double_q_learning_d5e_5 type: batch repeat: 5 until: (cycle >= 100000) {
	parameter 'input_time?' var: input_time <- true;
	parameter 'exp_decay' var: exp_decay <- 5.0E-5;
	parameter 'simulation_steps' var: simulation_steps <- 100000;
	parameter 'max_damaged_cars' var: max_damaged_cars <- 4;
	parameter 'discount_factor' var: discount_factor <- 0.98;
	parameter 'dynamic_situation' var: dynamic_situation <- true;
	parameter 'acceleration' var: acceleration <- 0.005;
	parameter 'exp_rate' var: exp_rate <- 1;
	parameter 'number_of_lanes_way' var: number_of_lanes_way <- 5;
	parameter 'clip_param' var: clip_param <- 0.2;
	parameter 'input_exp' var: input_exp <- true;
	parameter 'save_experience' var: save_experience <- false;
	parameter 'batch_size' var: batch_size <- 128;
	parameter 'driving_policy' var: driving_policy <- "Double Q-Learning";
	parameter 'memory_size' var: memory_size <- 100000;
	parameter 'max_patience' var: max_patience <- 50;
	parameter 'multiple_workers' var: multiple_workers <- false;
	parameter 'number_of_cars' var: number_of_cars <- 100;
	parameter 'deceleration' var: deceleration <- 0.02;
	parameter 'learning_rate' var: learning_rate <- 0.0034;
	reflex save_results {
		save [mean([speed] of (cars where (each.speed > 0))), mean([reward] of (cars where (each.speed > 0))), nb_collisions, timer] to: "results_double_q_learning_d5e_5.csv" type: csv rewrite: false;
	}
}

experiment double_q_learning_d3_33e_5 type: batch repeat: 5 until: (cycle >= 100000) {
	parameter 'input_time?' var: input_time <- true;
	parameter 'exp_decay' var: exp_decay <- 3.333333E-5;
	parameter 'simulation_steps' var: simulation_steps <- 100000;
	parameter 'max_damaged_cars' var: max_damaged_cars <- 4;
	parameter 'discount_factor' var: discount_factor <- 0.98;
	parameter 'dynamic_situation' var: dynamic_situation <- true;
	parameter 'acceleration' var: acceleration <- 0.005;
	parameter 'exp_rate' var: exp_rate <- 1;
	parameter 'number_of_lanes_way' var: number_of_lanes_way <- 5;
	parameter 'clip_param' var: clip_param <- 0.2;
	parameter 'input_exp' var: input_exp <- true;
	parameter 'save_experience' var: save_experience <- false;
	parameter 'batch_size' var: batch_size <- 128;
	parameter 'driving_policy' var: driving_policy <- "Double Q-Learning";
	parameter 'memory_size' var: memory_size <- 100000;
	parameter 'max_patience' var: max_patience <- 50;
	parameter 'multiple_workers' var: multiple_workers <- false;
	parameter 'number_of_cars' var: number_of_cars <- 100;
	parameter 'deceleration' var: deceleration <- 0.02;
	parameter 'learning_rate' var: learning_rate <- 0.0034;
	reflex save_results {
		save [mean([speed] of (cars where (each.speed > 0))), mean([reward] of (cars where (each.speed > 0))), nb_collisions, timer] to: "results_double_q_learning_d3_33e_5.csv" type: csv rewrite: false;
	}
}

experiment double_q_learning_d2_5e_5 type: batch repeat: 5 until: (cycle >= 100000) {
	parameter 'input_time?' var: input_time <- true;
	parameter 'exp_decay' var: exp_decay <- 2.5E-5;
	parameter 'simulation_steps' var: simulation_steps <- 100000;
	parameter 'max_damaged_cars' var: max_damaged_cars <- 4;
	parameter 'discount_factor' var: discount_factor <- 0.98;
	parameter 'dynamic_situation' var: dynamic_situation <- true;
	parameter 'acceleration' var: acceleration <- 0.005;
	parameter 'exp_rate' var: exp_rate <- 1;
	parameter 'number_of_lanes_way' var: number_of_lanes_way <- 5;
	parameter 'clip_param' var: clip_param <- 0.2;
	parameter 'input_exp' var: input_exp <- true;
	parameter 'save_experience' var: save_experience <- false;
	parameter 'batch_size' var: batch_size <- 128;
	parameter 'driving_policy' var: driving_policy <- "Double Q-Learning";
	parameter 'memory_size' var: memory_size <- 100000;
	parameter 'max_patience' var: max_patience <- 50;
	parameter 'multiple_workers' var: multiple_workers <- false;
	parameter 'number_of_cars' var: number_of_cars <- 100;
	parameter 'deceleration' var: deceleration <- 0.02;
	parameter 'learning_rate' var: learning_rate <- 0.0034;
	reflex save_results {
		save [mean([speed] of (cars where (each.speed > 0))), mean([reward] of (cars where (each.speed > 0))), nb_collisions, timer] to: "results_double_q_learning_d2_5e_5.csv" type: csv rewrite: false;
	}
}