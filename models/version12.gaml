/**
* Name: version11
* Based on the internal skeleton template. 
* Author: Admin
* Tags: 
*/

model version12

global {
	float step <- 0.1#s;
	/** Insert the global definitions, variables and actions here */
	file my_file <- csv_file("../includes/new_road.csv",",");
	file total_emission_file <- csv_file("total_emission.csv",",");
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
        create vehicle_controller;
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
        	state <- 2;
        	//duration <- light_duration;
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
			//duration <- light_duration;		
        }
        
        // 1. Tạo tiêu đề cho file chi tiết từng giây
        save ["Cycle", "Giay_thu", "CO_tuc_thoi_g", "HC_tuc_thoi_g", "NOx_tuc_thoi_g", "CO_tich_luy_g", "HC_tich_luy_g", "NOx_tich_luy_g"] 
             to: "../results/emission_each_second.csv" format: "csv" rewrite: true header: false;
             
        // 2. Tạo tiêu đề cho file tổng kết cuối cùng
        save ["Tong_thoi_gian_s", "Tong_CO_g", "Tong_HC_g", "Tong_NOx_g", "TB_CO_moi_giay_g"] 
             to: "../results/total_emission.csv" format: "csv" rewrite: true header: false;
             
    }
    
    float dir_change_percentage <- 0.2;
    float standard_max_speed <- 50.0;
    float standard_min_speed <- 3.0;
    float standard_speed <- 5.0;
    float standard_car_speed <- 40.0;
    float standard_motorbike_speed <- 30.0;
    float standard_bike_speed <- 15.0;
    float standard_speed_change <- 2.5;
    
    //thong so phat thai
    float motorbike_co_ef <- 12.09;
    float motorbike_hc_ef <- 1.02;
    float motorbike_nox_ef <- 0.11;
    
    float car_co_ef <- 2.21;
    float car_hc_ef <- 0.26;
    float car_nox_ef <- 1.05;
    float car_pm_ef <- 0.3;

    
    int nb_car_up;
    int nb_car_left;
    int nb_car_right;
    int nb_car_down;
    int nb_bike_up;
    int nb_bike_right;
    int nb_bike_down;
    int nb_bike_left;
    int nb_motorbike_up;
    int nb_motorbike_right;
    int nb_motorbike_down;
    int nb_motorbike_left;
    
    //monitor
    int total_car_moves <- 0;
	int total_motorbike_moves <- 0;
	int total_bike_moves <- 0;
	int car_moves_this_cycle <- 0;
	int motorbike_moves_this_cycle <- 0;
	int bike_moves_this_cycle <- 0;
	int car_moves_last_cycle <- 0;
	int motorbike_moves_last_cycle <- 0;
	int bike_moves_last_cycle <- 0;
    reflex update when: (cycle mod 10 = 0) {
    	//tong phat thai
    	total_car_moves <- total_car_moves + car_moves_this_cycle;
    	total_motorbike_moves <- total_motorbike_moves + motorbike_moves_this_cycle;
    	total_bike_moves <- total_bike_moves + bike_moves_this_cycle;
    	
    	//luu lai gia tri cycle truuoc
    	car_moves_last_cycle <- car_moves_this_cycle;
    	motorbike_moves_last_cycle <- motorbike_moves_this_cycle;
    	bike_moves_last_cycle <- bike_moves_this_cycle;
    	
    	//reset
    	car_moves_this_cycle <- 0;
    	motorbike_moves_this_cycle <- 0;
    	motorbike_moves_this_cycle <- 0;
    }
    
    reflex export_csv when: every (1#s) {
        
        // rewrite: false để ghi nối tiếp vào các dòng dưới, header: false để không lặp lại tiêu đề
        save [cycle, time, 
        	(car_moves_last_cycle * car_co_ef + motorbike_moves_last_cycle * motorbike_co_ef )* 0.001, 
        	(car_moves_last_cycle * car_hc_ef + motorbike_moves_last_cycle * motorbike_hc_ef) * 0.001,
        	(car_moves_last_cycle * car_nox_ef + motorbike_moves_last_cycle * motorbike_nox_ef) * 0.001,
        	(total_car_moves * car_co_ef + total_motorbike_moves * motorbike_co_ef) * 0.001, 
        	(total_car_moves * car_hc_ef + total_motorbike_moves * motorbike_hc_ef) * 0.001,
        	(total_car_moves * car_nox_ef + total_motorbike_moves * motorbike_nox_ef) * 0.001 
        	
        ] 
             to: "../results/emission_each_second.csv" format: "csv" rewrite: false header: false;
    }
    
    // Hành động tự động kích hoạt KHI KẾT THÚC EXPERIMENT (bấm nút Stop/Reload hoặc hết thời gian)
    abort {
        
        save [time, 
              with_precision((total_car_moves * car_co_ef + total_motorbike_moves * motorbike_co_ef) * 0.001, 2), 
              with_precision((total_car_moves * car_hc_ef + total_motorbike_moves * motorbike_hc_ef) * 0.001, 2), 
              with_precision((total_car_moves * car_nox_ef + total_motorbike_moves * motorbike_nox_ef) * 0.001, 2)
              ]
              to: "../results/total_emission.csv" format: "csv" rewrite: false header: false;
             
        write "Đã xuất xong dữ liệu tổng kết vào thư mục results!";
    }
}

grid road_cell width: 50 height: 50 neighbors: 8 {
	int direction <- -1; // UP RIGHT DOWN LEFT
	bool r <- false;
	bool l <- false;
	bool u <- false;
	bool d <- false;
	
	int cell_value;
	
	reflex update_cell_value when: (cycle mod 10 = 0) {
		cell_value <- traffic_light_on[grid_x, grid_y];
	}

	list<road_cell> neighbors <- (self neighbors_at 1);
	//list<road_cell> neighbor_at_1_fin <- neighbor_at_1_raw where (!(each.direction = 0));
	aspect base {
		//draw string(grid_x) at: location + {0,0,5} color: #black font: font("Arial", 10);
		//draw line([{0, (25 * cell_height)}, {10, 25}]) color: #white;
		if (grid_y = 25) {
			if (grid_x < 10 or grid_x >= 40) {
				draw line([{grid_x * self.shape.width, grid_y * self.shape.height}, {(grid_x+1) * self.shape.width, grid_y * self.shape.height}])
                	color: #white
                	width: 2;
			}
		}
		
		if (grid_x = 25) {
			if (grid_y < 10 or grid_y >= 40) {
				draw line([{grid_x * self.shape.width, grid_y * self.shape.height}, {grid_x * self.shape.width, (grid_y+1) * self.shape.height}])
                	color: #white
                	width: 2;
			}
		}
	}
}

species traffic_light {
//	float green_time <- 30.0;
//	float red_time <- 40.0;
//	float orange_time <- 10.0;
	list<int> duration <- [40, 50, 10];
	
	int state <- 1; // 1 = red, 0 = green, 2 = yellow red -> yellow -> green -> red
	rgb light_color;
	list<counter_presenter> presenters;
	int counter <- 0;
	list<road_cell> owned_cells;
	list<road_cell> side_cells;
	
	
	reflex update_counter when: (cycle mod 10 = 0) {
		counter <- counter + 1;
		int current_duration <- duration[state];
		ask presenters {
			num <- current_duration - myself.counter;
		}
	}
	
	reflex update_duration when: (cycle mod 10 = 0) {
		duration[0] <- int(light_duration * 0.7);
		duration[2] <- light_duration - duration[0];
		duration[1] <- light_duration;
	}
	
	reflex change_state when: (cycle mod 10 = 0) {
		if (counter >= duration[state]) {
			counter <- 0;
			if (state = 2) {
				state <- 0;
				ask owned_cells {
					traffic_light_on[grid_x, grid_y] <- 0;
				}
			} else if (state = 0) {
				state <- 1;
				ask owned_cells {
					traffic_light_on[grid_x, grid_y] <- 1;
				}
			} else if (state = 1) {
				state <- 2;
			}
		}
	}
	
	reflex update_color when: (cycle mod 10 = 0) {
		if (state = 0) {
			light_color <- #green;
		} else if (state = 1) {
			light_color <- #red;
		} else {
			light_color <- #yellow;
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

species vehicle_controller {
	int nb_vehicles_up_lane;
	int nb_vehicles_left_lane;
	int nb_vehicles_down_lane;
	int nb_vehicles_right_lane;
	int nb_vehicles_roundabout;
	
	int count_vehicle (int side) {
		return 0;
	}
	
	reflex count when: (cycle mod 5 = 0) {
		//nb_vehicles_up_lane <- 
	}
	
	bool isUpFree {
		int available_slots <- 0;
		loop i over: up_start {
			if (map_occupied[i.grid_x, i.grid_y] = 0) {
				available_slots <- available_slots + 1;
			}
		}
		if (available_slots = 0){
			return false;
		} else {
			return true;
		}
	}
	
	bool isRightFree {
		int available_slots <- 0;
		loop i over: right_start {
			if (map_occupied[i.grid_x, i.grid_y] = 0) {
				available_slots <- available_slots + 1;
			}
		}
		if (available_slots = 0){
			return false;
		} else {
			return true;
		}
	}
	
	bool isDownFree {
		int available_slots <- 0;
		loop i over: down_start {
			if (map_occupied[i.grid_x, i.grid_y] = 0) {
				available_slots <- available_slots + 1;
			}
		}
		if (available_slots = 0){
			return false;
		} else {
			return true;
		}
	}
	
	bool isLeftFree {
		int available_slots <- 0;
		loop i over: left_start {
			if (map_occupied[i.grid_x, i.grid_y] = 0) {
				available_slots <- available_slots + 1;
			}
		}
		if (available_slots = 0){
			return false;
		} else {
			return true;
		}
	}

	reflex generate when: every(2#s){
		if (isUpFree()) {
			create car number: nb_car_up * rnd(1) {
				dest <- one_of (end_points);
				loop while: (dest = "UP_END") {
					dest <- one_of (end_points);
				}
				start <- "UP_START";
				my_cell <- one_of (up_start);
	        	main_dir <- 2;
	        	heading <- -90.0;
	        	int loop_cnt <- 0;
	        	loop while: (map_occupied[my_cell.grid_x, my_cell.grid_y] = 1 and loop_cnt < 5) {
	        		loop_cnt <- loop_cnt + 1;
	        		my_cell <- one_of (up_start);
		        	main_dir <- 2;
	        	}
	        	map_occupied[my_cell.grid_x, my_cell.grid_y] <- 1;
	        	location <- my_cell.location;
			}
			
			create motorbike number: nb_motorbike_up * rnd(1) {
				dest <- one_of (end_points);
				loop while: (dest = "UP_END") {
					dest <- one_of (end_points);
				}
				start <- "UP_START";
				my_cell <- one_of (up_start);
	        	main_dir <- 2;
	        	heading <- -90.0;
	        	int loop_cnt <- 0;
	        	loop while: (map_occupied[my_cell.grid_x, my_cell.grid_y] = 1 and loop_cnt < 5) {
	        		loop_cnt <- loop_cnt + 1;
	        		my_cell <- one_of (up_start);
		        	main_dir <- 2;
	        	}
	        	map_occupied[my_cell.grid_x, my_cell.grid_y] <- 1;
	        	location <- my_cell.location;
			}
			
			create bike number: nb_bike_up * rnd(1) {
				dest <- one_of (end_points);
				loop while: (dest = "UP_END") {
					dest <- one_of (end_points);
				}
				start <- "UP_START";
				my_cell <- one_of (up_start);
	        	main_dir <- 2;
	        	heading <- -90.0;
	        	int loop_cnt <- 0;
	        	loop while: (map_occupied[my_cell.grid_x, my_cell.grid_y] = 1 and loop_cnt < 5) {
	        		loop_cnt <- loop_cnt + 1;
	        		my_cell <- one_of (up_start);
		        	main_dir <- 2;
	        	}
	        	map_occupied[my_cell.grid_x, my_cell.grid_y] <- 1;
	        	location <- my_cell.location;
			}
		}
		if (isRightFree()) {
			create car number: nb_car_right * rnd(1){
				dest <- one_of (end_points);
				loop while: (dest = "RIGHT_END") {
					dest <- one_of (end_points);
				}
				start <- "RIGHT_START";
				my_cell <- one_of (right_start);
	        	main_dir <- 3;
	        	heading <- 180.0;
	        	int loop_cnt <- 0;
	        	loop while: (map_occupied[my_cell.grid_x, my_cell.grid_y] = 1 and loop_cnt < 5) {
	        		loop_cnt <- loop_cnt + 1;
	        		my_cell <- one_of (right_start);
		        	main_dir <- 3;
	        	}
	        	map_occupied[my_cell.grid_x, my_cell.grid_y] <- 1;
	        	location <- my_cell.location;
			}
			
			create motorbike number: nb_motorbike_right * rnd(1){
				dest <- one_of (end_points);
				loop while: (dest = "RIGHT_END") {
					dest <- one_of (end_points);
				}
				start <- "RIGHT_START";
				my_cell <- one_of (right_start);
	        	main_dir <- 3;
	        	heading <- 180.0;
	        	int loop_cnt <- 0;
	        	loop while: (map_occupied[my_cell.grid_x, my_cell.grid_y] = 1 and loop_cnt < 5) {
	        		loop_cnt <- loop_cnt + 1;
	        		my_cell <- one_of (right_start);
		        	main_dir <- 3;
	        	}
	        	map_occupied[my_cell.grid_x, my_cell.grid_y] <- 1;
	        	location <- my_cell.location;
			}
			
			create bike number: nb_bike_right * rnd(1){
				dest <- one_of (end_points);
				loop while: (dest = "RIGHT_END") {
					dest <- one_of (end_points);
				}
				start <- "RIGHT_START";
				my_cell <- one_of (right_start);
	        	main_dir <- 3;
	        	heading <- 180.0;
	        	int loop_cnt <- 0;
	        	loop while: (map_occupied[my_cell.grid_x, my_cell.grid_y] = 1 and loop_cnt < 5) {
	        		loop_cnt <- loop_cnt + 1;
	        		my_cell <- one_of (right_start);
		        	main_dir <- 3;
	        	}
	        	map_occupied[my_cell.grid_x, my_cell.grid_y] <- 1;
	        	location <- my_cell.location;
			}
		}
		if (isDownFree()) {
			create car number: nb_car_down * rnd(1){
				dest <- one_of (end_points);
				loop while: (dest = "DOWN_END") {
					dest <- one_of (end_points);
				}
				start <- "DOWN_START";
				my_cell <- one_of (down_start);
	        	main_dir <- 0;
	        	heading <- 90.0;
	        	int loop_cnt <- 0;
	        	loop while: (map_occupied[my_cell.grid_x, my_cell.grid_y] = 1 and loop_cnt < 5) {
	        		loop_cnt <- loop_cnt + 1;
	        		my_cell <- one_of (down_start);
		        	main_dir <- 0;
	        	}
	        	map_occupied[my_cell.grid_x, my_cell.grid_y] <- 1;
	        	location <- my_cell.location;
			}
			create motorbike number: nb_motorbike_down * rnd(1){
				dest <- one_of (end_points);
				loop while: (dest = "DOWN_END") {
					dest <- one_of (end_points);
				}
				start <- "DOWN_START";
				my_cell <- one_of (down_start);
	        	main_dir <- 0;
	        	heading <- 90.0;
	        	int loop_cnt <- 0;
	        	loop while: (map_occupied[my_cell.grid_x, my_cell.grid_y] = 1 and loop_cnt < 5) {
	        		loop_cnt <- loop_cnt + 1;
	        		my_cell <- one_of (down_start);
		        	main_dir <- 0;
	        	}
	        	map_occupied[my_cell.grid_x, my_cell.grid_y] <- 1;
	        	location <- my_cell.location;
			}
			create bike number: nb_bike_down * rnd(1){
				dest <- one_of (end_points);
				loop while: (dest = "DOWN_END") {
					dest <- one_of (end_points);
				}
				start <- "DOWN_START";
				my_cell <- one_of (down_start);
	        	main_dir <- 0;
	        	heading <- 90.0;
	        	int loop_cnt <- 0;
	        	loop while: (map_occupied[my_cell.grid_x, my_cell.grid_y] = 1 and loop_cnt < 5) {
	        		loop_cnt <- loop_cnt + 1;
	        		my_cell <- one_of (down_start);
		        	main_dir <- 0;
	        	}
	        	map_occupied[my_cell.grid_x, my_cell.grid_y] <- 1;
	        	location <- my_cell.location;
			}
		}
		if (isLeftFree()) {
			create car number: nb_car_left * rnd(1){
				dest <- one_of (end_points);
				loop while: (dest = "LEFT_END") {
					dest <- one_of (end_points);
				}
				start <- "LEFT_START";
				my_cell <- one_of (left_start);
	        	main_dir <- 1;
	        	heading <- 0.0;
	        	int loop_cnt <- 0;
	        	loop while: (map_occupied[my_cell.grid_x, my_cell.grid_y] = 1 and loop_cnt < 5) {
	        		loop_cnt <- loop_cnt + 1;
	        		my_cell <- one_of (left_start);
		        	main_dir <- 1;
	        	}
	        	map_occupied[my_cell.grid_x, my_cell.grid_y] <- 1;
	        	location <- my_cell.location;
			}
			
			create motorbike number: nb_motorbike_left * rnd(1){
				dest <- one_of (end_points);
				loop while: (dest = "LEFT_END") {
					dest <- one_of (end_points);
				}
				start <- "LEFT_START";
				my_cell <- one_of (left_start);
	        	main_dir <- 1;
	        	heading <- 0.0;
	        	int loop_cnt <- 0;
	        	loop while: (map_occupied[my_cell.grid_x, my_cell.grid_y] = 1 and loop_cnt < 5) {
	        		loop_cnt <- loop_cnt + 1;
	        		my_cell <- one_of (left_start);
		        	main_dir <- 1;
	        	}
	        	map_occupied[my_cell.grid_x, my_cell.grid_y] <- 1;
	        	location <- my_cell.location;
			}
			
			create bike number: nb_bike_left * rnd(1){
				dest <- one_of (end_points);
				loop while: (dest = "LEFT_END") {
					dest <- one_of (end_points);
				}
				start <- "LEFT_START";
				my_cell <- one_of (left_start);
	        	main_dir <- 1;
	        	heading <- 0.0;
	        	int loop_cnt <- 0;
	        	loop while: (map_occupied[my_cell.grid_x, my_cell.grid_y] = 1 and loop_cnt < 5) {
	        		loop_cnt <- loop_cnt + 1;
	        		my_cell <- one_of (left_start);
		        	main_dir <- 1;
	        	}
	        	map_occupied[my_cell.grid_x, my_cell.grid_y] <- 1;
	        	location <- my_cell.location;
			}
		}
	
//		create motorbike number: nb_motorbike_up * rnd(1) {
//			dest <- one_of (end_points);
//			loop while: (dest = "UP_END") {
//				dest <- one_of (end_points);
//			}
//			start <- "UP_START";
//			my_cell <- one_of (up_start);
//        	main_dir <- 2;
//        	heading <- -90.0;
//        	int loop_cnt <- 0;
//        	loop while: (map_occupied[my_cell.grid_x, my_cell.grid_y] = 1 and loop_cnt < 5) {
//        		loop_cnt <- loop_cnt + 1;
//        		my_cell <- one_of (up_start);
//	        	main_dir <- 2;
//        	}
//        	map_occupied[my_cell.grid_x, my_cell.grid_y] <- 1;
//        	location <- my_cell.location;
//		}
		
		
		
		
		
		
		
		
//		create car number: nb_car_up {
//			dest <- one_of (end_points);
//			
//			list<string> start_points <- myself.getStartPoints(dest);
//			start <- one_of (start_points);
//        	
//        	if (start = "UP_START") {
//        		my_cell <- one_of (up_start);
//        		main_dir <- 2;
//        	} else if (start = "RIGHT_START") {
//        		my_cell <- one_of (right_start);
//        		main_dir <- 3;
//        	} else if (start = "DOWN_START") {
//        		my_cell <- one_of (down_start);
//        		main_dir <- 0;
//        	} else if (start = "LEFT_START") {
//        		my_cell <- one_of (left_start);
//        		main_dir <- 1;
//        	}
//        	
//        	loop while: (map_occupied[my_cell.grid_x, my_cell.grid_y] = 1) {
//        		if (start = "UP_START") {
//	        		my_cell <- one_of (up_start);
//	        		main_dir <- 2;
//	        	} else if (start = "RIGHT_START") {
//	        		my_cell <- one_of (right_start);
//	        		main_dir <- 3;
//	        	} else if (start = "DOWN_START") {
//	        		my_cell <- one_of (down_start);
//	        		main_dir <- 0;
//	        	} else if (start = "LEFT_START") {
//	        		my_cell <- one_of (left_start);
//	        		main_dir <- 1;
//	        	}
//        	}
//        	map_occupied[my_cell.grid_x, my_cell.grid_y] <- 1;
//        	location <- my_cell.location;
//		}
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

//species monitor {
//	int total_car_moves;
//	int total_motorbike_moves;
//	int total_bike_moves;
//	int car_moves_each_cycle;
//	int motorbike_moves_each_cycle;
//	int bike_moves_each_cycle;
//	
//	reflex update {
//		
//	}
//	
//}

species vehicle {
	//float standard_speed <- 30.0; //30 km/h thì đi được 1 ô trong 1s
	float current_speed;
	float standard_move_time <- 1.0;
	float move_time <- 2.0; // Mặc định để 2s
	float min_speed <- 10.0;
	float max_speed <- 80.0;
	float speed_change <- gauss (standard_speed_change, 1);
	float vehicle_speed_change_rate;
	int main_dir; // 0 = U, 1 = R, 2 = D, 3 = L
	float heading;
	road_cell my_cell;
	string dest;
	string start;
	int state <- 0; // 0 = Accel, 1 = Slow down
	
	int steps_per_cycle <- 1;
	int min_steps <-  0;
	int max_steps <- 3;
	
	rgb color <- #blue;
	
	int width;
	int length;
	
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
	
	action addMoves;
	
	reflex basic_move when: every(move_time#s) {
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
				heading <- 0.0;
				do go_right;
			} else 
			if (map_occupied[next.grid_x, next.grid_y] = 1) {
				do handle_stuck;
			} else
			{
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 0;
				my_cell <- next;
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 1;
				do addMoves;
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
				heading <- -90.0;
				do go_down;
			} else 
			if (map_occupied[next.grid_x, next.grid_y] = 1) {
				do handle_stuck;
			} else
			{
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 0;
				my_cell <- next;
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 1;
				do addMoves;
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
				heading <- 180.0;
				do go_left;
			} else 
			if (map_occupied[next.grid_x, next.grid_y] = 1) {
				do handle_stuck;
			} else
			 {
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 0;
				my_cell <- next;
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 1;
				do addMoves;
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
				heading <- 90.0;
				do go_up;
			} else 
			if (map_occupied[next.grid_x, next.grid_y] = 1) {
				do handle_stuck;
			} else
			{
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 0;
				my_cell <- next;
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 1;
				do addMoves;
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
			do addMoves;
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
			do addMoves;
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

		} else if (checkRight2()) {
			state <- 1;
			do addMoves;
			//write "go right";
			if (main_dir = 1) {
				//do go_down;
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 0;
				my_cell <- one_of (my_cell.neighbors where (my_cell.grid_y + 1 <= 49 and my_cell.grid_x + 1 <= 49 
					and each.grid_y = my_cell.grid_y + 1 and each.grid_x = my_cell.grid_x + 1
				));
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 1;
			}

			if (main_dir = 3) {
				//do go_up;
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 0;
				my_cell <- one_of (my_cell.neighbors where (my_cell.grid_y - 1 >= 0 and my_cell.grid_x - 1 >= 0 
					and each.grid_y = my_cell.grid_y - 1 and each.grid_x = my_cell.grid_x - 1
				));
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 1;
			}

			if (main_dir = 0) {
				//do go_right;
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 0;
				my_cell <- one_of (my_cell.neighbors where (my_cell.grid_x + 1 <= 49 and my_cell.grid_y - 1 >= 0
					and each.grid_x = my_cell.grid_x + 1 and each.grid_y = my_cell.grid_y - 1
				));
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 1;
			}

			if (main_dir = 2) {
				//do go_left;
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 0;
				my_cell <- one_of (my_cell.neighbors where (my_cell.grid_x - 1 >= 0 and my_cell.grid_y + 1 <= 49
					and each.grid_x = my_cell.grid_x - 1 and each.grid_y = my_cell.grid_y + 1
				));
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 1;
			}
		} else if (checkLeft2()) {
			state <- 1;
			do addMoves;
			//write "go left";
			if (main_dir = 1) {
				//do go_up;
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 0;
				my_cell <- one_of (my_cell.neighbors where (my_cell.grid_y - 1 >= 0 and my_cell.grid_x + 1 <= 49 
					and each.grid_y = my_cell.grid_y - 1 and each.grid_x = my_cell.grid_x + 1
				));
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 1;
			}

			if (main_dir = 3) {
				//do go_down;
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 0;
				my_cell <- one_of (my_cell.neighbors where (my_cell.grid_y + 1 <= 49 and my_cell.grid_x - 1 >= 0 
					and each.grid_y = my_cell.grid_y + 1 and each.grid_x = my_cell.grid_x - 1
				));
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 1;
			}

			if (main_dir = 0) {
				//do go_left;
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 0;
				my_cell <- one_of (my_cell.neighbors where (my_cell.grid_x - 1 >= 0 and my_cell.grid_y - 1 >= 0 
					and each.grid_x = my_cell.grid_x - 1 and each.grid_y = my_cell.grid_y - 1
				));
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 1;
			}

			if (main_dir = 2) {
				//do go_right;
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 0;
				my_cell <- one_of (my_cell.neighbors where (my_cell.grid_x + 1 <= 49 and my_cell.grid_y + 1 <= 49
					and each.grid_x = my_cell.grid_x + 1 and each.grid_y = my_cell.grid_y + 1
				));
				map_occupied[my_cell.grid_x, my_cell.grid_y] <- 1;
			}

		} else {
			//write "remain stuck";
			//current_speed <- 0.0;
			do slow_down;
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
					heading <- 90.0;
				} else {
					if (my_cell.d) {
						if (my_cell.r) {
							main_dir <- 1;
							heading <- 0.0;
						}
					}
				}
			} else if (dest = "RIGHT_END") {
				if (my_cell.r) {
					main_dir <- 1;
					heading <- 0.0;
				} else {
					if (my_cell.l) {
						if (my_cell.d) {
							main_dir <- 2;
							heading <- -90.0;
						}
					}
				}
			} else if (dest = "DOWN_END") {
				if (my_cell.d) {
					main_dir <- 2;
					heading <- -90.0;
				} else {
					if (my_cell.u) {
						if (my_cell.l) {
							main_dir <- 3;
							heading <- 180.0;
						}
					}
				}
			} else if (dest = "LEFT_END") {
				if (my_cell.l) {
					main_dir <- 3;
					heading <- 180.0;
				} else {
					if (my_cell.d) {
						if (my_cell.u) {
							main_dir <- 0;
							heading <- 90.0;
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
			current_speed <- current_speed + speed_change * vehicle_speed_change_rate;
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
    bool checkRight2 {
    	int my_x <- my_cell.grid_x;
		int my_y <- my_cell.grid_y;
    	if (main_dir = 0) {
    		my_y <- my_y - 1;
    		int sum <- 0;
    		if (!(isInside(my_x+1, my_y) and isInside(my_x + 1, my_y + 1) and isInside(my_x + 1, my_y - 1))) {
    			return false;
    		}
    		road_cell next <- one_of (my_cell.neighbors where (my_cell.grid_x+1 = each.grid_x and my_cell.grid_y-1 = each.grid_y));
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
			my_x <- my_x + 1;
			int sum <- 0;
    		if (!(isInside(my_x - 1, my_y + 1) and isInside(my_x, my_y + 1) and isInside(my_x + 1, my_y + 1))) {
    			return false;
    		}
    		sum <- map_occupied[my_x - 1, my_y + 1] + map_occupied[my_x, my_y + 1] + map_occupied[my_x + 1, my_y + 1];
    		road_cell next <- one_of (my_cell.neighbors where (my_cell.grid_x+1 = each.grid_x and my_cell.grid_y + 1 = each.grid_y));
    		if (!next.r) {
    			return false;
    		}
			if (sum > 0) {
				return false;
			} else {
				return true;
			}
		} else if (main_dir = 2) {
			my_y <- my_y + 1;
			int sum <- 0;
    		if (!(isInside(my_x - 1, my_y - 1) and isInside(my_x - 1, my_y) and isInside(my_x - 1, my_y + 1))) {
    			return false;
    		}
    		sum <- map_occupied[my_x - 1, my_y - 1] + map_occupied[my_x - 1, my_y] + map_occupied[my_x - 1, my_y + 1];
    		road_cell next <- one_of (my_cell.neighbors where (my_cell.grid_x - 1 = each.grid_x and my_cell.grid_y+1 = each.grid_y));
    		if (!next.d) {
    			return false;
    		}
			if (sum > 0) {
				return false;
			} else {
				return true;
			}
		} else if (main_dir = 3) {
			my_x <- my_x - 1;
			int sum <- 0;
    		if (!(isInside(my_x, my_y - 1) and isInside(my_x - 1, my_y - 1) and isInside(my_x + 1, my_y - 1))) {
    			return false;
    		}
    		sum <- map_occupied[my_x - 1, my_y - 1] + map_occupied[my_x, my_y - 1] + map_occupied[my_x + 1, my_y - 1];
    		road_cell next <- one_of (my_cell.neighbors where (my_cell.grid_x-1 = each.grid_x and my_cell.grid_y - 1 = each.grid_y));
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
    
    bool checkLeft2 {
    	int my_x <- my_cell.grid_x;
		int my_y <- my_cell.grid_y;
    	if (main_dir = 2) {
    		my_y <- my_y + 1;
    		int sum <- 0;
    		if (!(isInside(my_x+1, my_y) and isInside(my_x + 1, my_y + 1) and isInside(my_x + 1, my_y - 1))) {
    			return false;
    		}
    		sum <- map_occupied[my_x + 1, my_y] + map_occupied[my_x + 1, my_y + 1] + map_occupied[my_x + 1, my_y - 1];
    		road_cell next <- one_of (my_cell.neighbors where (my_cell.grid_x+1 = each.grid_x and my_cell.grid_y+1 = each.grid_y));
    		if (!next.d) {
    			return false;
    		}
			if (sum > 0) {
				return false;
			} else {
				return true;
			}
		} else if (main_dir = 3) {
			my_x <- my_x - 1;
			int sum <- 0;
    		if (!(isInside(my_x - 1, my_y + 1) and isInside(my_x, my_y + 1) and isInside(my_x + 1, my_y + 1))) {
    			return false;
    		}
    		sum <- map_occupied[my_x - 1, my_y + 1] + map_occupied[my_x, my_y + 1] + map_occupied[my_x + 1, my_y + 1];
    		road_cell next <- one_of (my_cell.neighbors where (my_cell.grid_x-1 = each.grid_x and my_cell.grid_y + 1 = each.grid_y));
    		if (!next.l){
    			return false;
    		}
			if (sum > 0) {
				return false;
			} else {
				return true;
			}
		} else if (main_dir = 0) {
			my_y <- my_y - 1;
			int sum <- 0;
    		if (!(isInside(my_x - 1, my_y - 1) and isInside(my_x - 1, my_y) and isInside(my_x - 1, my_y + 1))) {
    			//write "turn left wrong 1";
    			return false;
    		}
    		sum <- map_occupied[my_x - 1, my_y - 1] + map_occupied[my_x - 1, my_y] + map_occupied[my_x - 1, my_y + 1];
    		road_cell next <- one_of (my_cell.neighbors where (my_cell.grid_x - 1 = each.grid_x and my_cell.grid_y-1 = each.grid_y));
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
			my_x <- my_x + 1;
			int sum <- 0;
    		if (!(isInside(my_x, my_y - 1) and isInside(my_x - 1, my_y - 1) and isInside(my_x + 1, my_y - 1))) {
    			return false;
    		}
    		sum <- map_occupied[my_x - 1, my_y - 1] + map_occupied[my_x, my_y - 1] + map_occupied[my_x + 1, my_y - 1];
    		road_cell next <- one_of (my_cell.neighbors where (my_cell.grid_x+1 = each.grid_x and my_cell.grid_y - 1 = each.grid_y));
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
    	if (x >= 10 and x <= 39 and y >= 10 and y <= 39 and x=y) {
    		return true;
    	}
    	if (x >= 10 and x <= 39 and y >= 10 and y <= 39 and x+y = 50) {
    		return true;
    	}
    	return false;
    }
	
	aspect base {
		draw circle (1) color: color;
		//draw string(dest) /* + " :" + current_speed*/ at: location + {0,0,5} color: #black font: font("Arial", 10);
	}
}

species car parent: vehicle {
	image_file my_icon <- image_file("../includes/car_right_3.png");
	init {
		max_speed <- gauss(standard_max_speed,5);
		current_speed <- gauss(standard_car_speed, 5);
		width <- 2;
		length <- 3;
		vehicle_speed_change_rate <- 2.0;
	}
	
	action addMoves {
		car_moves_this_cycle <- car_moves_this_cycle + 1;
	}
	
	aspect base {
		draw my_icon size: {2.0, 2.0} rotate: -heading;
		//draw string(with_precision(move_time, 2)) at: location + {0,0,5} color: #black font: font("Arial", 10);
	}
}

species motorbike parent: vehicle {
	image_file my_icon <- image_file("../includes/mtbike.png");
	init {
		max_speed <- gauss(standard_max_speed-10,5);
		current_speed <- gauss(standard_motorbike_speed, 5);
		width <- 1;
		length <- 2;
		vehicle_speed_change_rate <- 1.5;
	}
	
	action addMoves {
		motorbike_moves_this_cycle <- motorbike_moves_this_cycle + 1;
	}
	
	aspect base {
		draw my_icon size: {1.5, 1.5} rotate: -heading;
		//draw string(with_precision(current_speed, 2)) at: location + {0,0,5} color: #black font: font("Arial", 10);
	}
}

species bike parent: vehicle {
	image_file my_icon <- image_file("../includes/bicycle.png");
	init {
		max_speed <- gauss(standard_max_speed - 20,5);
		current_speed <- gauss(standard_bike_speed, 1);
		width <- 1;
		length <- 2;
		vehicle_speed_change_rate <- 1.0;
	}
	
	action addMoves {
		bike_moves_this_cycle <- bike_moves_this_cycle + 1;
	}
	
	aspect base {
		//draw square(1) color: color;
		draw my_icon size: {1.5, 1.5} rotate: -heading;
		//draw string(with_precision(current_speed, 2)) at: location + {0,0,5} color: #black font: font("Arial", 10);
	}
}

experiment version12 type: gui {
	/** Insert here the definition of the input and output of the model */
	parameter "Thòi gian đèn đỏ" var: light_duration <- 30 min: 20 max: 120;
	parameter "UP car freq" var: nb_car_up <- 1 min: 0 max: 3;
	parameter "RIGHT car freq" var: nb_car_right <- 1 min: 0 max: 3;
	parameter "DOWN car freq" var: nb_car_down <- 1 min: 0 max: 3;
	parameter "LEFT car freq" var: nb_car_left <- 1 min: 0 max: 3;
	
	parameter "UP motorbike freq" var: nb_motorbike_up <- 1 min: 0 max: 3;
	parameter "RIGHT motorbike freq" var: nb_motorbike_right <- 1 min: 0 max: 3;
	parameter "DOWN motorbike freq" var: nb_motorbike_down <- 1 min: 0 max: 3;
	parameter "LEFT motorbike freq" var: nb_motorbike_left <- 1 min: 0 max: 3;
	
	parameter "UP bike freq" var: nb_bike_up <- 1 min: 0 max: 3;
	parameter "RIGHT bike freq" var: nb_bike_right <- 1 min: 0 max: 3;
	parameter "DOWN bike freq" var: nb_bike_down <- 1 min: 0 max: 3;
	parameter "LEFT bike freq" var: nb_bike_left <- 1 min: 0 max: 3;
	
	output {
		display MyDisplay type: java2D {
			
            grid road_cell;
            species road_cell aspect: base;
            //species vehicle aspect:base;
            species counter_presenter aspect:base;
            species car aspect:base;
            species motorbike aspect:base;
            species bike aspect:base;
            //species my_species aspect: default; 
//            graphics "Thong so" {
//            	draw rectangle(20, 20)
//            	at: {10, 90}
//            	color: #white;
//                draw "Làn UP: " + length(car)
//                    at: {3, 83}
//                    color: #red
//                    font: font("Arial", 12, #bold);
//                draw "Làn RIGHT: " + length(car)
//                    at: {3, 91}
//                    color: #red
//                    font: font("Arial", 12, #bold);
//                draw "Làn LEFT: " + length(car)
//                    at: {3, 87}
//                    color: #red
//                    font: font("Arial", 12, #bold);
//                draw "Làn DOWN: " + length(car)
//                    at: {3, 96}
//                    color: #red
//                    font: font("Arial", 12, #bold);
//            }
        }
        display emission_time_series type: java2D {
		    chart "Biểu đồ phát thải tại mỗi s" type: series x_label: "Giây" y_label: "Khối lượng phát thải (g)"{
		        data "CO (g)" value: (car_moves_last_cycle * car_co_ef + motorbike_moves_last_cycle * motorbike_co_ef) * 0.001 color: #orange;
		        data "NOx (g)" value: (car_moves_last_cycle * car_nox_ef + motorbike_moves_last_cycle * motorbike_nox_ef) * 0.001 color: #red;
		        data "HC (g)" value: (car_moves_last_cycle * car_hc_ef + motorbike_moves_last_cycle * motorbike_hc_ef) * 0.001 color: #green;
		    }
		}
		
		display total_emission type: java2D {
		    chart "Biểu đồ tổng phát thải theo thời gian" type: series {
		        data "CO (g)" value: (total_car_moves * car_co_ef + total_motorbike_moves * motorbike_co_ef) * 0.001 color: #orange;
		        data "NOx (g)" value: (total_car_moves * car_nox_ef + total_motorbike_moves * motorbike_nox_ef) * 0.001 color: #red;
		        data "HC (g)" value: (total_car_moves * car_hc_ef + total_motorbike_moves * motorbike_hc_ef) * 0.001 color: #green;
		    }
		}
//        display MatrixDisplay {
//        	grid road_cell border: #black;
//        	agents "Labels" value: road_cell {
//                draw string(cell_value) at: location color: #black font: font("Arial", 14) anchor: #center;
//            }
//        }
	}
}
