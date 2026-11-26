/**
* Name: expressways_from_netlogo
* Based on the internal skeleton template. 
* Author: Admin
* Tags: 
*/

model expressways_from_netlogo

/* ---------------------------
   GLOBAL PARAMETERS (map từ NetLogo globals)
   --------------------------- */
global {
  // lane & world
  int nb_lanes <- 4;                 // tổng số làn xe (vd: 4)
  int lane_width_patches <- 1;       // chiều rộng 1 patch ~ 1/2 lane (tinh chỉnh)
  int world_width <- 120;            // số cell ngang (patches) - tương ứng chiều NetLogo
  int world_height <- 40;            // số cell dọc (patches)
  int road_start_y <- 10;            // vị trí bắt đầu vùng đường theo trục y (có thể dùng để dịch chuyển)
  int nb_cars <- 100;                // số xe ban đầu

  // speed & movement (đơn vị: cell per tick)
  float speed_min <- 0.5;
  float speed_max <- 2.0;
  float emergency_stop_speed <- 0.2;

  // lane change & safety
  float collision_distance <- 1.5;   // khoảng cách gây va chạm (cell)
  int change_lane_step <- 1;         // bước chuyển làn theo patch
  float lane_change_prob <- 0.4;     // xác suất muốn chuyển làn khi có lý do

  // damaged car (xe hỏng - map từ prob-damaged-car, durations...)
  float prob_damaged_car <- 0.002;   // xác suất mỗi tick 1 xe bị hỏng
  int damaged_inlane_duration_max <- 80;    // ticks
  int damaged_inrescue_duration_max <- 120; // ticks

  // logging / counters
  int nb_collisions <- 0;
  int nb_damaged <- 0;

  // visualization toggles
  bool show_grid <- true;
  bool show_lane_lines <- true;

  // init hook (khởi tạo/Nhận xét)
  init {
    write("Expressways GAML initialized.");
  }
}

/* ---------------------------
   GRID: mô phỏng patches (NetLogo patches -> GAMA grid cells)
   Sử dụng grid 2D rời rạc để giữ logic tương tự NetLogo
   --------------------------- */
grid road_space type: discrete cell_size: 1 width: world_width height: world_height {
  // thuộc tính cell (patch)
  bool is_road <- false;
  int lane_index <- -1;         // -1 nếu không phải lane, else 0..nb_lanes-1
  float traffic_density <- 0.0;
  color base_color <- #white;
}

/* ---------------------------
   SPECIES: vehicle (map từ breed [cars car])
   --------------------------- */
species vehicle skills: [ moving ] {
  // thuộc tính tương tự NetLogo turtles-own
  int id <- 0;
  float speed <- 1.0;            // cell/tick
  int lane <- 0;                 // lane index (0..nb_lanes-1)
  bool damaged <- false;         // xe bị hỏng
  int damaged_ticks <- 0;        // đếm thời gian bị hỏng
  float heading_angle <- 0.0;    // 0 = tiến theo trục +x (sang phải)
  int desired_lane <- -1;        // lane muốn chuyển tới (nếu có)
  color v_color <- rgb(0,0,255);

  // khởi tạo mỗi vehicle khi create
  init {
    // mặc định đang hướng sang phải
    heading_angle <- 0.0;
    speed <- speed_min + rnd() * (speed_max - speed_min);
    v_color <- rgb(31, 119, 180); // mặc định xanh dương
  }

  /*
    Reflex di chuyển: chạy mỗi tick
    - Nếu damaged: đứng yên hoặc di chuyển chậm ở lane rescue
    - Nếu không: cố gắng tiến theo lane, xử lý chuyển làn nếu cần
  */
  reflex step when: every (1#minute) {
    if (damaged) {
      // xử lý xe hỏng: đứng yên hoặc rất chậm
      damaged_ticks <- damaged_ticks + 1;
      if (damaged_ticks > damaged_inlane_duration_max) {
        // đưa xe vào rescue lane giả (ở lề) - đơn giản: đặt speed nhỏ
        speed <- emergency_stop_speed;
      } else {
        speed <- 0.0;
      }
      // damaged car vẫn báo trên bản đồ với màu đỏ
      v_color <- rgb(214, 39, 40);
      // không di chuyển nếu speed == 0
      if (speed > 0) {
        do move_to_next_cell();
      }
      // có thể sửa chữa ngẫu nhiên (giảm damaged sau thời gian)
      if (damaged_ticks > damaged_inrescue_duration_max) {
        damaged <- false;
        damaged_ticks <- 0;
        nb_damaged <- nb_damaged - 1;
      }
      stop;
    }

    // 1) xác suất bị hỏng ngẫu nhiên (theo NetLogo prob-damaged-car)
    if (rnd() < prob_damaged_car) {
      damaged <- true;
      damaged_ticks <- 0;
      nb_damaged <- nb_damaged + 1;
      v_color <- rgb(214, 39, 40);
      stop;
    }
    

    // 2) phát hiện xe phía trước trong cùng lane và giữ khoảng cách
    vehicle ahead <- detect_vehicle_ahead(collision_distance);
    if (ahead != nil) {
      // nếu quá gần → giảm tốc / dừng / thử chuyển làn
      if (distance_to(ahead) <= collision_distance) {
        // va chạm!
        nb_collisions <- nb_collisions + 1;
        // giảm tốc mạnh
        speed <- max(speed_min, ahead.speed * 0.5);
      } else {
        // điều chỉnh tốc độ theo vehicle ahead
        speed <- min(speed, ahead.speed);
      }

      // thử chuyển làn sang trái hoặc phải nếu an toàn & muốn vượt
      if (rnd() < lane_change_prob) {
        int l_left <- lane - 1;
        int l_right <- lane + 1;
        if (l_left >= 0 and can_change_to_lane(l_left)) {
          desired_lane <- l_left;
          do change_lane_to(desired_lane);
        } else if (l_right < nb_lanes and can_change_to_lane(l_right)) {
          desired_lane <- l_right;
          do change_lane_to(desired_lane);
        }
      }
    } else {
      // không có xe phía trước trong khoảng collision_distance
      // tăng tốc trở lại tới speed_max
      if (speed < speed_max) {
        speed <- min(speed_max, speed + 0.1);
      }
    }

    // 3) di chuyển về phía trước
    do move_to_next_cell();

    // 4) nếu ra khỏi bản đồ → respawn (tương tự NetLogo wrap hoặc recreate)
    if (x >= road_space.width) {
      // quay về bên trái (respawn) hoặc remove+create
      // ở đây: respawn bên trái với vị trí y tương tự lane
      set_x_y(-1, lane_to_y(lane));
      speed <- speed_min + rnd() * (speed_max - speed_min);
    }
  }

  /* ---- Actions/helpers ---- */
  action move_to_next_cell {
    // move theo heading_angle (0 tức sang phải). Dùng 'move' từ skill moving
    // trước khi move, set target theo speed (number of cells)
    // simple discrete move by rounding speed to int
    int step_cells <- max(1, round(speed));
    // di chuyển từng cell một để dễ kiểm tra va chạm
    int i <- 0;
    while (i < step_cells) {
      // tính vị trí tiếp theo sang phải (x+1)
      int nx <- x + 1;
      int ny <- y;
      // nếu target cell không phải road → cố gắng tìm cell cùng hàng (không di chuyển)
      if (nx >= 0 and nx < road_space.width and cell_at(nx, ny).is_road) {
        move_to cell_at(nx, ny);
      } else {
        // nếu không, dừng hoặc giữ ở edge
        // đặt x = road_space.width to cause respawn in reflex
        set_x_y(road_space.width + 1, y);
        break;
      }
      i <- i + 1;
    }
  }

  action detect_vehicle_ahead(float dist) returns vehicle {
    // trả về vehicle cùng lane nằm phía trước gần nhất trong khoảng dist (x tăng)
    list vehicles_ahead <- (agents(vehicle) where: [self.lane = lane and self.x > x]);
    if (vehicles_ahead.is_empty) { return nil; }
    // tìm min x
    vehicle closest <- first(sort(vehicles_ahead, [ [a,b] -> a.x < b.x ]));
    if (closest.x - x <= dist) { return closest; }
    return nil;
  }

  action can_change_to_lane(int target_lane) returns bool {
    // kiểm tra an toàn chuyển lane: cell cạnh cùng x ở target_lane không có vehicle
    int ty <- lane_to_y(target_lane);
    if (ty < 0 or ty >= road_space.height) { return false; }
    // kiểm tra một số cell phía trước và phía sau trong lane mục tiêu
    int look_ahead <- 2;
    int i <- -1;
    while (i <= look_ahead) {
      int cx <- x + i;
      if (cx >= 0 and cx < road_space.width) {
        cell c <- cell_at(cx, ty);
        if (c != nil) {
          if (c.agents_of_type(vehicle).size > 0) {
            return false;
          }
        }
      }
      i <- i + 1;
    }
    return true;
  }

  action change_lane_to(int target_lane) {
    int ty <- lane_to_y(target_lane);
    if (ty >= 0 and ty < road_space.height) {
      move_to cell_at(x, ty);
      lane <- target_lane;
    }
  }

  // tiện ích: map lane index -> y coordinate trên grid
  action lane_to_y(int ln) returns int {
    // giả định lane 0 ở phía dưới (road_start_y) và tăng lên trên
    return road_start_y + ln * lane_width_patches;
  }

  // tiện ích: truy vấn cell theo toạ độ
  action cell_at(int cx, int cy) returns cell {
    if (cx < 0 or cx >= road_space.width or cy < 0 or cy >= road_space.height) { return nil; }
    return road_space.cell(cx, cy);
  }

  // khoảng cách ước lượng theo x (do grid)
  action distance_to(vehicle v) returns float {
    return abs(v.x - x);
  }

  /* Visualization aspect */
  aspect default {
    shape: circle;
    size: 1;
    color: v_color;
    // rotate theo heading (nếu cần)
  }
}

/* ---------------------------
   EXPERIMENT GUI - thiết lập và vẽ bản đồ
   --------------------------- */
experiment expressways_gui type: gui {
  output map type: map {
    /* Hiển thị grid + vehicles */
    display {
      // show grid cells
      // layer road cells
      layer name: "roads" {
        draw cells where: [is_road = true] as: rect {
          thickness: 0.1;
          // color tùy thuộc lane
          color: ifelse (self.lane_index % 2 = 0) then (#e6e6e6) else (#dcdcdc);
        }
      }
      // vehicles layer (GAMA tự vẽ species theo aspect)
      layer name: "vehicles" {
        draw agents of: vehicle;
      }
    } // end display
  } // end map output

  // Controls & init
  init {
    // 1) khởi tạo grid cells (road_space tự tạo ra theo khai báo grid)
    // 2) mark một dải cells làm đường (multiple lanes)
    // xác định vùng đường: chiều dài = world_width, lanes từ road_start_y
    int lx <- 0;
    while (lx < road_space.width) {
      int ln <- 0;
      while (ln < nb_lanes) {
        int cy <- road_start_y + ln * lane_width_patches;
        if (cy >= 0 and cy < road_space.height) {
          cell c <- road_space.cell(lx, cy);
          c.is_road <- true;
          c.lane_index <- ln;
          c.base_color <- #f2f2f2;
        }
        ln <- ln + 1;
      }
      lx <- lx + 1;
    }

    // 3) tạo vehicles rải trên đường
    int i <- 0;
    while (i < nb_cars) {
      // chọn lane ngẫu nhiên và vị trí x ngẫu nhiên trên phần đầu đường
      int ln <- rndint(0, nb_lanes - 1);
      int px <- rndint(0, floor(world_width * 0.6));
      int py <- road_start_y + ln * lane_width_patches;
      create vehicle 1 {
        id <- self.index;
        lane <- ln;
        set_x_y(px, py);
        speed <- speed_min + rnd() * (speed_max - speed_min);
        v_color <- #1f77b4;
      }
      i <- i + 1;
    }
  } // end init

  // Controls shown in GUI
  parameter nb_cars type: int min: 0 max: 1000 step: 1 value: nb_cars;
  parameter speed_max type: float min: 0.1 max: 10.0 step: 0.1 value: speed_max;
  parameter prob_damaged_car type: float min: 0.0 max: 1.0 step: 0.0001 value: prob_damaged_car;
  parameter lane_change_prob type: float min: 0.0 max: 1.0 step: 0.01 value: lane_change_prob;

  // run button / stop
  runtime {
    display: map;
    // tốc độ tick
    delay: 50;
  }
}
