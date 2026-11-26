/**
* Name: version11
* Based on the internal skeleton template. 
* Author: Admin
* Tags: 
*/

model version11

global {
	/** Insert the global definitions, variables and actions here */
	file my_file <- csv_file("../includes/new_road.csv",",");
	list<road_cell> in_road;
	//list<string> start_points <- ["UP_START", "RIGHT_START", "DOWN_START", "LEFT_START"];
	list<string> end_points <- ["UP_END", "RIGHT_END", "DOWN_END", "LEFT_END"]; // U_E: y = 0, R_E: x = 49, D_E: y = 49, L_E: y = 0
	list<int> y_up_starts <- 10 to 24;
	list<int> y_down_starts <- 25 to 39;
	list<int> x_right_starts <- 10 to 24;
	list<int> x_left_starts <- 25 to 39;
	
	list<road_cell> up_start;
	list<road_cell> right_start;
	list<road_cell> down_start;
	list<road_cell> left_start;
	
	int light_duration;
	
	matrix<int> map_occupied <- 0 as_matrix ({50, 50});
	matrix<int> traffic_light_on <- 0 as_matrix ({50,50});
	init {
        //matrix data <- matrix(my_csv_file);
        matrix my_matrix <- matrix(my_file);
        ask road_cell {
            grid_value <- float(my_matrix[grid_x,grid_y]);
            //write ("" + grid_x + ":" + grid_y);
            //write(grid_value);
            //map occupied get data
            if (grid_value = 0) {
            	map_occupied[grid_x, grid_y] <- 2;
            }
            //write my_matrix[grid_x,grid_y];
            direction <- grid_value;
            if (!(direction = 0)) {
            	color <- #gray;
            }
            int tmp <- direction;
            if (float(tmp)/2 > int(tmp/2)) {
            	u <- true;
            } else {
            	u <- false;
            }
            tmp <- tmp/2;
            if (float(tmp)/2 > int(tmp/2)) {
            	r <- true;
            } else {
            	r <- false;
            }
            tmp <- tmp/2;
            if (float(tmp)/2 > int(tmp/2)) {
            	d <- true;
            } else {
            	d <- false;
            }
            tmp <- tmp/2;
            if (float(tmp)/2 > int(tmp/2)) {
            	l <- true;
            } else {
            	l <- false;
            }
            
        }
        
        list<string> getStartPoints(string endpoint) {
        	if (endpoint = "UP_END") {
        		return ["RIGHT_START", "DOWN_START", "LEFT_START"];
        	} else if (endpoint = "RIGHT_END") {
        		return ["UP_START", "DOWN_START", "LEFT_START"];
        	} else if (endpoint = "DOWN_END") {
        		return ["UP_START", "RIGHT_START", "LEFT_START"];
        	} else if (endpoint = "LEFT_END") {
        		return ["UP_START", "RIGHT_START", "DOWN_START"];
        	}
        	return [];
        }
        
        in_road <- road_cell where (!(each.direction = 0));
        
        up_start <- road_cell where (each.grid_y = 0 and y_up_starts contains each.grid_x);
        right_start <- road_cell where (each.grid_x = 49 and x_right_starts contains each.grid_y);
        down_start <- road_cell where (each.grid_y = 49 and y_down_starts contains each.grid_x);
        left_start <- road_cell where (each.grid_x = 0 and x_left_starts contains each.grid_y);
        
        list<road_cell> traffic_light_vertical_cells <- road_cell where ((each.grid_y = 9 and y_up_starts contains each.grid_x) 
        	or (each.grid_y = 40 and y_down_starts contains each.grid_x));
		list<road_cell> traffic_light_horizontal_cells <- road_cell where ((each.grid_x = 40 and x_right_starts contains each.grid_y) 
        	or (each.grid_x = 9 and x_left_starts contains each.grid_y));
        
        //create vehicle number:50;
        create vehicle_generator;
        create counter_presenter {
        	type <- 0;
        	my_cell <- one_of(road_cell where (each.grid_y = 9 and each.grid_x = 9));
        	location <- my_cell.location;
        }
        create counter_presenter {
        	type <- 0;
        	my_cell <- one_of(road_cell where (each.grid_y = 40 and each.grid_x = 40));
        	location <- my_cell.location;
        }
        create counter_presenter {
        	type <- 1;
        	my_cell <- one_of(road_cell where (each.grid_y = 9 and each.grid_x = 40));
        	location <- my_cell.location;
        }
        create counter_presenter {
        	type <- 1;
        	my_cell <- one_of(road_cell where (each.grid_y = 40 and each.grid_x = 9));
        	location <- my_cell.location;
        }
        create traffic_light {
        	owned_cells <- traffic_light_vertical_cells;
        	presenters <- counter_presenter where (each.type = 0);
        	side_cells <- road_cell where ((each.grid_y = 9 and each.grid_x = 9)
        		or (each.grid_y = 40 and each.grid_x = 40)
        	);
        	state <- 0;
        	duration <- light_duration;
        }
        
        create traffic_light {
        	owned_cells <- traffic_light_horizontal_cells;
        	presenters <- counter_presenter where (each.type = 1);
        	side_cells <- road_cell where ((each.grid_y = 9 and each.grid_x = 40)
        		or (each.grid_y = 40 and each.grid_x = 9)
        	);
        	state <- 1;
        	ask owned_cells {
				traffic_light_on[grid_x, grid_y] <- 1;
			}
			duration <- light_duration;
        }
    }
    
    float dir_change_percentage <- 0.2;
    
}

grid road_cell width: 50 height: 50 neighbors: 4 {
	int direction <- -1; // UP RIGHT DOWN LEFT
	bool r <- false;
	bool l <- false;
	bool u <- false;
	bool d <- false;
	
	int cell_value;
	
	reflex update_cell_value {
		cell_value <- traffic_light_on[grid_x, grid_y];
	}

	list<road_cell> neighbors <- (self neighbors_at 1);
	//list<road_cell> neighbor_at_1_fin <- neighbor_at_1_raw where (!(each.direction = 0));
	aspect base {
		//draw string(cell_value) at: location + {0,0,5} color: #black font: font("Arial", 10);
	}
}

species traffic_light {
//	float green_time <- 30.0;
//	float red_time <- 40.0;
//	float orange_time <- 10.0;
	int duration <- 30;
	
	int state <- 1; // 1 = red, 0 = green
	rgb light_color;
	list<counter_presenter> presenters;
	int counter <- 0;
	list<road_cell> owned_cells;
	list<road_cell> side_cells;
	
	
	reflex update_counter {
		counter <- counter + 1;
		ask presenters {
			num <- myself.counter;
		}
	}
	
	reflex update_duration {
		duration <- light_duration;
	}
	
	reflex change_state {
		if (counter >= duration) {
			counter <- 0;
			state <- 1 - state;
			if (state = 0) {
				ask owned_cells {
					traffic_light_on[grid_x, grid_y] <- 0;
				}
			} else if (state = 1) {
				ask owned_cells {
					traffic_light_on[grid_x, grid_y] <- 1;
				}
			}
			write "changed state";
		}
	}
	
	reflex update_color {
		if (state = 0) {
			light_color <- #green;
		} else {
			light_color <- #red;
		}
		do set_color;
	}
	
	action set_color {
		rgb l_color <- light_color;
		ask owned_cells {
			color <- l_color;
		}
	}
}

species counter_presenter {
	
	int num;
	road_cell my_cell;
	int type; // 0 = vertical, 1 = horizontal
	
	aspect base {
		draw string(num) at: location + {-1,1} color: #black font: font("Arial", 10);
	}
}

species vehicle_generator {
	int nb <- 3;
	
	int give1 {
		return 1;
	}

	reflex generate {
		create vehicle number: nb {
			dest <- one_of (end_points);
			//write ("" + my_cell.grid_x + ":" + my_cell.grid_y);
			
			list<string> start_points <- myself.getStartPoints(dest);
			start <- one_of (start_points);
			//write start;
			
//			if (start = "UP_START") {
//        		int my_x <- 0;
//        		int my_y <- one_of (y_up_starts);
//        		write ("" + my_x + ":" + my_y);
//        		my_cell <- road_cell(my_x, my_y);
//        		write ("" + road_cell(my_x, my_y).grid_x + ":" + road_cell(my_x, my_y).grid_y);
//        		
//        	} else if (start = "RIGHT_START") {
//        		int my_x <- one_of (x_right_starts);
//        		int my_y <- 49;
//        		write ("" + my_x + ":" + my_y);
//        		my_cell <- road_cell(my_x, my_y);
//        	} else if (start = "DOWN_START") {
//        		int my_x <- 49;
//        		int my_y <- one_of (y_down_starts);
//        		write ("" + my_x + ":" + my_y);
//        		my_cell <- road_cell(my_x, my_y);
//        	} else if (start = "LEFT_START") {
//        		int my_x <- one_of (x_left_starts);
//        		int my_y <- 0;
//        		write ("" + my_x + ":" + my_y);
//        		my_cell <- road_cell(my_x, my_y);
//        	}
        	
        	if (start = "UP_START") {
        		my_cell <- one_of (up_start);
        		main_dir <- 2;
        	} else if (start = "RIGHT_START") {
        		my_cell <- one_of (right_start);
        		main_dir <- 3;
        	} else if (start = "DOWN_START") {
        		my_cell <- one_of (down_start);
        		main_dir <- 0;
        	} else if (start = "LEFT_START") {
        		my_cell <- one_of (left_start);
        		main_dir <- 1;
        	}
        	
        	map_occupied[my_cell.grid_x, my_cell.grid_y] <- 1;
        	
        	//write ("" + my_cell.grid_x + ":" + my_cell.grid_y);
        	location <- my_cell.location;
        	//write ("" + my_cell.grid_x + ":" + my_cell.grid_y);
//			if (start = "UP_START") {
//        		int my_x <- 0;
//        		int my_y <- one_of (y_up_starts);
//        		my_cell <- road_cell(my_x, my_y);
//        		write ("" + my_x + ":" + my_y);
//        	} else if (start = "RIGHT_START") {
//        		int my_x <- one_of (x_right_starts);
//        		int my_y <- 49;
//        		my_cell <- road_cell(my_x, my_y);
//        	} else if (start = "DOWN_START") {
//        		int my_x <- 49;
//        		int my_y <- one_of (y_down_starts);
//        		my_cell <- road_cell(my_x, my_y);
//        	} else if (start = "LEFT_START") {
//        		int my_x <- 0;
//        		int my_y <- one_of (x_left_starts);
//        		my_cell <- road_cell(my_x, my_y);
//        	}
//        	location <- my_cell.location;
		}
	}
	list<string> getStartPoints(string endpoint) {
        	if (endpoint = "UP_END") {
        		return ["RIGHT_START", "DOWN_START", "LEFT_START"];
        	} else if (endpoint = "RIGHT_END") {
        		return ["UP_START", "DOWN_START", "LEFT_START"];
        	} else if (endpoint = "DOWN_END") {
        		return ["UP_START", "RIGHT_START", "LEFT_START"];
        	} else if (endpoint = "LEFT_END") {
        		return ["UP_START", "RIGHT_START", "DOWN_START"];
        	}
        	return [];
        }
        
    
}

species vehicle {
	float standard_speed <- 30.0; //30 km/h thì đi được 1 ô trong 1s
	float current_speed <- standard_speed;
	float standard_move_time <- 2.0;
	float move_time <- 2.0; // Mặc định để 2s
	float min_speed <- 10.0;
	float max_speed <- 80.0;
	float speed_change <- 5.0;
	int main_dir; // 0 = U, 1 = R, 2 = D, 3 = L
	road_cell my_cell;
	string dest;
	string start;
	int state <- 0; // 0 = Accel, 1 = Slow down
	
	int steps_per_cycle <- 1;
	int min_steps <-  0;
	int max_steps <- 3;
	
	rgb color <- #blue;
	
	//road_cell my_cell <- one_of (in_road);
	init {
		
		//my_cell <- one_of (in_road);
//		if (my_cell.u) {
//			main_dir <- 0;
//		}
//		if (my_cell.r) {
//			main_dir <- 1;
//		}
//		if (my_cell.d) {
//			main_dir <- 2;
//		}
//		if (my_cell.l) {
//			main_dir <- 3;
//		}
		//my_cell <- road_cell(1,1);
		//location <- my_cell.location;
		
		
		
        	//write ("" + my_cell.grid_x + ":" + my_cell.grid_y);
        	//location <- my_cell.location;
	}
	
	reflex basic_move when: every(move_time#cycle) {
//		if (checkForward4(my_cell.grid_x, my_cell.grid_y)) {
//			state <- 0;
//		} else {
//			state <- 1;
//			if (checkRight1()) {
//				if (main_dir = 1) {
//					do go_down;
//				}
//				if (main_dir = 3) {
//					do go_up;
//				}
//				if (main_dir = 0) {
//					do go_right;
//				}
//				if (main_dir = 2) {
//					do go_left;
//				}
//			} else if (checkLeft1()) {
//				if (main_dir = 1) {
//					do go_up;
//				}
//				if (main_dir = 3) {
//					do go_down;
//				}
//				if (main_dir = 0) {
//					do go_left;
//				}
//				if (main_dir = 2) {
//					do go_right;
//				}
//			}
//		}
		if (traffic_light_on[my_cell.grid_x, my_cell.grid_y] = 1) {
			//do handle_stuck;
		} else {
			if (main_dir = 1) {
				do go_right;
			}
			if (main_dir = 3) {
				do go_left;
			}
			if (main_dir = 0) {
				do go_up;
			}
			if (main_dir = 2) {
				do go_down;
			}
		}
	}
	
	reflex update_speed {
		if (traffic_light_on[my_cell.grid_x, my_cell.grid_y] = 1) {
			do stop;
		} else if (checkForward(my_cell.grid_x, my_cell.grid_y, 4)) {
			state <- 0;
			do accelerate;
		} else if (checkForward(my_cell.grid_x, my_cell.grid_y, 2)) {
			state <- 1;
			do slow_down;
			//write "Slow down at " + my_cell.grid_x + ":" + my_cell.grid_y; 
		} else if (!checkForward(my_cell.grid_x, my_cell.grid_y, 1)) {
			do handle_stuck;
//				if (checkRight1()) {
//					write "go right";
//					if (main_dir = 1) {
//						do go_down;
//					}
//					if (main_dir = 3) {
//						do go_up;
//					}
//					if (main_dir = 0) {
//						do go_right;
//					}
//					if (main_dir = 2) {
//						do go_left;
//					}
//				} else if (checkLeft1()) {
//					write "go left";
//					if (main_dir = 1) {
//						do go_up;
//					}
//					if (main_dir = 3) {
//						do go_down;
//					}
//					if (main_dir = 0) {
//						do go_left;
//					}
//					if (main_dir = 2) {
//						do go_right;
//					}
//				}
		}
			
		
//		if (state = 0) {
//			do accelerate;
//		} else {
//			do slow_down;
//		}
	}
	
	reflex update_move_time {
		if (current_speed = 0) {
			color <- #red;
			move_time <- 4.0;
		} else {
			color <- #blue;
			move_time <- (standard_speed / current_speed) * standard_move_time;
		}
	}
	
	action go_up {
		if (my_cell.grid_y - 1 < 0) {
			do go_die;
			
		}
		road_cell next;
		next <- one_of (my_cell.neighbors where (my_cell.grid_y - 1 >= 0 and each.grid_y = my_cell.grid_y - 1 and each.grid_x = my_cell.grid_x));
		if (next != nil) {
			//write ("check in pos " + next.grid_x + " : " + next.grid_y);
			if (map_occupied[next.grid_x, next.grid_y] = 2) {
				main_dir <- 1;
				do go_right;
			} else 
			if (map_occupied[next.grid_x, next.grid_y] = 1) {
				do handle_stuck;
			} else
			{
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 0;
				my_cell <- next;
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 1;
			}
			
		}
		do update_pos;
	}
	
	action go_right {
		if (my_cell.grid_x + 1 > 49) {
			do go_die;
		}
		road_cell next <- one_of (my_cell.neighbors where (my_cell.grid_x + 1 <= 49 and each.grid_x = my_cell.grid_x + 1 and each.grid_y = my_cell.grid_y));
		if (next != nil) {
			//write ("check in pos " + next.grid_x + " : " + next.grid_y);
			if (map_occupied[next.grid_x, next.grid_y] = 2) {
				main_dir <- 2;
				do go_down;
			} else 
			if (map_occupied[next.grid_x, next.grid_y] = 1) {
				do handle_stuck;
			} else
			{
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 0;
				my_cell <- next;
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 1;
			}
		}
		do update_pos;
	}
	
	action go_down {
		if (my_cell.grid_y + 1 > 49) {
			do go_die;
		}
		road_cell next <- one_of (my_cell.neighbors where (my_cell.grid_y + 1 <= 49 and each.grid_y = my_cell.grid_y + 1 and each.grid_x = my_cell.grid_x));
		if (next != nil) {
			//write ("check in pos " + next.grid_x + " : " + next.grid_y);
			if (map_occupied[next.grid_x, next.grid_y] = 2) {
				main_dir <- 3;
				do go_left;
			} else 
			if (map_occupied[next.grid_x, next.grid_y] = 1) {
				do handle_stuck;
			} else
			 {
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 0;
				my_cell <- next;
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 1;
			}
		}
		do update_pos;
	}
	
	action go_left {
		if (my_cell.grid_x - 1 < 0) {
			do go_die;
		}
		road_cell next <- one_of (my_cell.neighbors where (my_cell.grid_x - 1 >= 0 and each.grid_x = my_cell.grid_x - 1 and each.grid_y = my_cell.grid_y));
		if (next != nil) {
			//write ("check in pos " + next.grid_x + " : " + next.grid_y);
			if (map_occupied[next.grid_x, next.grid_y] = 2) {
				main_dir <- 0;
				do go_up;
			} else 
			if (map_occupied[next.grid_x, next.grid_y] = 1) {
				do handle_stuck;
			} else
			{
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 0;
				my_cell <- next;
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 1;
			}
		}
		do update_pos;
	}
	
	action handle_stuck {
		if (checkForward(my_cell.grid_x, my_cell.grid_y, 1)) {
			//write ("phia truoc trong");
			state <- 1;
			do accelerate;
		} else if (checkRight1()) {
			state <- 1;
			//write "go right";
			if (main_dir = 1) {
				//do go_down;
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 0;
				my_cell <- one_of (my_cell.neighbors where (my_cell.grid_y + 1 <= 49 and each.grid_y = my_cell.grid_y + 1 and each.grid_x = my_cell.grid_x));
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 1;
			}

			if (main_dir = 3) {
				//do go_up;
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 0;
				my_cell <- one_of (my_cell.neighbors where (my_cell.grid_y - 1 >= 0 and each.grid_y = my_cell.grid_y - 1 and each.grid_x = my_cell.grid_x));
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 1;
			}

			if (main_dir = 0) {
				//do go_right;
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 0;
				my_cell <- one_of (my_cell.neighbors where (my_cell.grid_x + 1 <= 49 and each.grid_x = my_cell.grid_x + 1 and each.grid_y = my_cell.grid_y));
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 1;
			}

			if (main_dir = 2) {
				//do go_left;
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 0;
				my_cell <- one_of (my_cell.neighbors where (my_cell.grid_x - 1 >= 0 and each.grid_x = my_cell.grid_x - 1 and each.grid_y = my_cell.grid_y));
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 1;
			}

		} else if (checkLeft1()) {
			state <- 1;
			//write "go left";
			if (main_dir = 1) {
				//do go_up;
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 0;
				my_cell <- one_of (my_cell.neighbors where (my_cell.grid_y - 1 >= 0 and each.grid_y = my_cell.grid_y - 1 and each.grid_x = my_cell.grid_x));
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 1;
			}

			if (main_dir = 3) {
				//do go_down;
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 0;
				my_cell <- one_of (my_cell.neighbors where (my_cell.grid_y + 1 <= 49 and each.grid_y = my_cell.grid_y + 1 and each.grid_x = my_cell.grid_x));
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 1;
			}

			if (main_dir = 0) {
				//do go_left;
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 0;
				my_cell <- one_of (my_cell.neighbors where (my_cell.grid_x - 1 >= 0 and each.grid_x = my_cell.grid_x - 1 and each.grid_y = my_cell.grid_y));
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 1;
			}

			if (main_dir = 2) {
				//do go_right;
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 0;
				my_cell <- one_of (my_cell.neighbors where (my_cell.grid_x + 1 <= 49 and each.grid_x = my_cell.grid_x + 1 and each.grid_y = my_cell.grid_y));
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 1;
			}

		} else {
			//write "remain stuck";
			current_speed <- 0.0;
			state <- -1;
		}

	}
	
	action change_to_left {
		//check vision
		if (main_dir = 0) {
			int next_x <- my_cell.grid_x-1;
			int next_y <- my_cell.grid_y;
			if (isInside(next_x, next_y) and map_occupied[next_x, next_y] = 0) { //ktra co the sang trai ko
				if (isInside(next_x, next_y)) {
					
				}
			}
		} else if (main_dir = 1) {
			
		} else if (main_dir = 2) {
			
		} else if (main_dir = 3) {
			
		}
	}
	
	action update_pos {
		location <- my_cell.location;
		
		// turning edge
		//if (my_cell.grid_x = my_cell.grid_y or my_cell.grid_x + my_cell.grid_y = 49) {
		if (isTurningEdge(my_cell.grid_x, my_cell.grid_y)){
			if (dest = "UP_END") {
				if (my_cell.u) {
					main_dir <- 0;
				} else {
					if (my_cell.d) {
						if (my_cell.r) {
							main_dir <- 1;
						}
					}
				}
			} else if (dest = "RIGHT_END") {
				if (my_cell.r) {
					main_dir <- 1;
				} else {
					if (my_cell.l) {
						if (my_cell.d) {
							main_dir <- 2;
						}
					}
				}
			} else if (dest = "DOWN_END") {
				if (my_cell.d) {
					main_dir <- 2;
				} else {
					if (my_cell.u) {
						if (my_cell.l) {
							main_dir <- 3;
						}
					}
				}
			} else if (dest = "LEFT_END") {
				if (my_cell.l) {
					main_dir <- 3;
				} else {
					if (my_cell.d) {
						if (my_cell.u) {
							main_dir <- 0;
						}
					}
				}
			}
		}
	}
	
	
	action slow_down {
		if (current_speed - speed_change <= min_speed) {
			current_speed <- min_speed;
		} else {
			current_speed <- current_speed - speed_change;
		}
	}
	
	action accelerate {
		if (current_speed + speed_change >= max_speed) {
			current_speed <- max_speed;
		} else {
			current_speed <- current_speed + speed_change;
		}
	}
	
	
	
	action stop {
		current_speed <- 0;
	}
	
	action go_die {
		map_occupied[my_cell.grid_x, my_cell.grid_y] <- 0;
		do die;
	}
	
	bool isInside (int x, int y) {
        if (x < 0 or x >= 50) {return false;}
      	if (y < 0 or y >= 50) {return false;}
      	return true;
    }
    
    bool checkForward (int my_x, int my_y, int steps) {
//    	int my_x <- my_cell.grid_x;
//		int my_y <- my_cell.grid_y;
    	if (main_dir = 0) {
			int sum <- 0;
			loop i from: 1 to: steps {
				if (isInside(my_x, my_y - i)) {
					int tmp <- map_occupied[my_x, my_y - i];
					sum <- sum + tmp;
				}
			}
			if (sum > 0) {
				//write sum;
				return false;
			} else {
				return true;
			}
		} else if (main_dir = 1) {
			int sum <- 0;
			loop i from: 1 to: steps {
				if (isInside(my_x + i, my_y)) {
					int tmp <- map_occupied[my_x+i, my_y];
					sum <- sum + tmp;
				}
			}
			if (sum > 0) {
				//write sum;
				return false;
			} else {
				return true;
			}
		} else if (main_dir = 2) {
			int sum <- 0;
			loop i from: 1 to: steps {
				if (isInside(my_x, my_y + i)) {
					int tmp <- map_occupied[my_x, my_y + i];
					sum <- sum + tmp;
				}
			}
			if (sum > 0) {
				//write sum;
				return false;
			} else {
				return true;
			}
		} else if (main_dir = 3) {
			int sum <- 0;
			loop i from: 1 to: steps {
				if (isInside(my_x - i, my_y)) {
					int tmp <- map_occupied[my_x - i, my_y];
					sum <- sum + tmp;
				}
			}
			if (sum > 0) {
				//write sum;
				return false;
			} else {
				return true;
			}
		}
    }
    
    
    bool checkRight1 {
    	int my_x <- my_cell.grid_x;
		int my_y <- my_cell.grid_y;
    	if (main_dir = 0) {
    		int sum <- 0;
    		if (!(isInside(my_x+1, my_y) and isInside(my_x + 1, my_y + 1) and isInside(my_x + 1, my_y - 1))) {
    			return false;
    		}
    		road_cell next <- one_of (my_cell.neighbors where (my_cell.grid_x+1 = each.grid_x and my_cell.grid_y = each.grid_y));
    		if (!next.u) {
    			return false;
    		}
    		sum <- map_occupied[my_x + 1, my_y] + map_occupied[my_x + 1, my_y + 1] + map_occupied[my_x + 1, my_y - 1];
			if (sum > 0) {
				return false;
			} else {
				return true;
			}
		} else if (main_dir = 1) {
			int sum <- 0;
    		if (!(isInside(my_x - 1, my_y + 1) and isInside(my_x, my_y + 1) and isInside(my_x + 1, my_y + 1))) {
    			return false;
    		}
    		sum <- map_occupied[my_x - 1, my_y + 1] + map_occupied[my_x, my_y + 1] + map_occupied[my_x + 1, my_y + 1];
    		road_cell next <- one_of (my_cell.neighbors where (my_cell.grid_x = each.grid_x and my_cell.grid_y + 1 = each.grid_y));
    		if (!next.r) {
    			return false;
    		}
			if (sum > 0) {
				return false;
			} else {
				return true;
			}
		} else if (main_dir = 2) {
			int sum <- 0;
    		if (!(isInside(my_x - 1, my_y - 1) and isInside(my_x - 1, my_y) and isInside(my_x - 1, my_y + 1))) {
    			return false;
    		}
    		sum <- map_occupied[my_x - 1, my_y - 1] + map_occupied[my_x - 1, my_y] + map_occupied[my_x - 1, my_y + 1];
    		road_cell next <- one_of (my_cell.neighbors where (my_cell.grid_x - 1 = each.grid_x and my_cell.grid_y = each.grid_y));
    		if (!next.d) {
    			return false;
    		}
			if (sum > 0) {
				return false;
			} else {
				return true;
			}
		} else if (main_dir = 3) {
			int sum <- 0;
    		if (!(isInside(my_x, my_y - 1) and isInside(my_x - 1, my_y - 1) and isInside(my_x + 1, my_y - 1))) {
    			return false;
    		}
    		sum <- map_occupied[my_x - 1, my_y - 1] + map_occupied[my_x, my_y - 1] + map_occupied[my_x + 1, my_y - 1];
    		road_cell next <- one_of (my_cell.neighbors where (my_cell.grid_x = each.grid_x and my_cell.grid_y - 1 = each.grid_y));
    		if (!next.l) {
    			return false;
    		}
			if (sum > 0) {
				return false;
			} else {
				return true;
			}
		}
    }
    
    bool checkLeft1 {
    	int my_x <- my_cell.grid_x;
		int my_y <- my_cell.grid_y;
    	if (main_dir = 2) {
    		int sum <- 0;
    		if (!(isInside(my_x+1, my_y) and isInside(my_x + 1, my_y + 1) and isInside(my_x + 1, my_y - 1))) {
    			return false;
    		}
    		sum <- map_occupied[my_x + 1, my_y] + map_occupied[my_x + 1, my_y + 1] + map_occupied[my_x + 1, my_y - 1];
    		road_cell next <- one_of (my_cell.neighbors where (my_cell.grid_x+1 = each.grid_x and my_cell.grid_y = each.grid_y));
    		if (!next.d) {
    			return false;
    		}
			if (sum > 0) {
				return false;
			} else {
				return true;
			}
		} else if (main_dir = 3) {
			int sum <- 0;
    		if (!(isInside(my_x - 1, my_y + 1) and isInside(my_x, my_y + 1) and isInside(my_x + 1, my_y + 1))) {
    			return false;
    		}
    		sum <- map_occupied[my_x - 1, my_y + 1] + map_occupied[my_x, my_y + 1] + map_occupied[my_x + 1, my_y + 1];
    		road_cell next <- one_of (my_cell.neighbors where (my_cell.grid_x = each.grid_x and my_cell.grid_y + 1 = each.grid_y));
    		if (!next.l){
    			return false;
    		}
			if (sum > 0) {
				return false;
			} else {
				return true;
			}
		} else if (main_dir = 0) {
			int sum <- 0;
    		if (!(isInside(my_x - 1, my_y - 1) and isInside(my_x - 1, my_y) and isInside(my_x - 1, my_y + 1))) {
    			//write "turn left wrong 1";
    			return false;
    		}
    		sum <- map_occupied[my_x - 1, my_y - 1] + map_occupied[my_x - 1, my_y] + map_occupied[my_x - 1, my_y + 1];
    		road_cell next <- one_of (my_cell.neighbors where (my_cell.grid_x - 1 = each.grid_x and my_cell.grid_y = each.grid_y));
    		if (!next.u) {
    			//write "turn left wrong 2";
    			return false;
    		}
			if (sum > 0) {
				//write "turn left wrong 3";
				return false;
			} else {
				return true;
			}
		} else if (main_dir = 1) {
			int sum <- 0;
    		if (!(isInside(my_x, my_y - 1) and isInside(my_x - 1, my_y - 1) and isInside(my_x + 1, my_y - 1))) {
    			return false;
    		}
    		sum <- map_occupied[my_x - 1, my_y - 1] + map_occupied[my_x, my_y - 1] + map_occupied[my_x + 1, my_y - 1];
    		road_cell next <- one_of (my_cell.neighbors where (my_cell.grid_x = each.grid_x and my_cell.grid_y - 1 = each.grid_y));
    		if (!next.r) {
    			return false;
    		}
			if (sum > 0) {
				return false;
			} else {
				return true;
			}
		}
    }
    
    bool isTurningEdge (int x, int y) {
    	if (x >= 10 and x <= 24 and y >= 10 and y <= 24 and x+y = 34) {
    		return true;
    	}
    	if (x >= 25 and x <= 39 and y >= 10 and y <= 24 and x+y = 49) {
    		return true;
    	}
    	if (x >= 10 and x <= 24 and y >= 25 and y <= 39 and x+y = 49) {
    		return true;
    	}
    	if (x >= 25 and x <= 39 and y >= 25 and y <= 39 and x+y = 64) {
    		return true;
    	}
    	return false;
    }
	
	aspect base {
		draw circle (1) color: color;
		draw string(dest) /* + " :" + current_speed*/ at: location + {0,0,5} color: #black font: font("Arial", 10);
	}
}

experiment version11 type: gui {
	/** Insert here the definition of the input and output of the model */
	parameter "Thòi gian đèn đỏ" var: light_duration <- 30 min: 20 max: 120;
	output {
		display MyDisplay type: java2D {
            grid road_cell border: #black ;
            species vehicle aspect:base;
            species counter_presenter aspect:base;
            //species my_species aspect: default; 
        }
//        display MatrixDisplay {
//        	grid road_cell border: #black;
//        	agents "Labels" value: road_cell {
//                draw string(cell_value) at: location color: #black font: font("Arial", 14) anchor: #center;
//            }
//        }
	}
}
