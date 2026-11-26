/**
* Name: movingpathfinder
* Based on the internal empty template. 
* Author: Admin
* Tags: 
*/


model moving_pathfinder

global {
    int grid_width <- 20;
    int grid_height <- 20;
    
    graph road_graph;
    my_grid target_cell; // Chỉ còn vị trí đích là cố định (hoặc đích cũng có thể động)

    init {
        // Khởi tạo vật cản ngẫu nhiên
        ask my_grid {
            type <- flip(0.15) ? 1 : 0; 
        }
        
        // Chỉ định ô đích (ví dụ góc dưới bên phải)
        target_cell <- my_grid[18, 18];
        target_cell.type <- 3;
        
        // Tạo xe tại ô [2, 2] làm vị trí xuất phát ban đầu
        create vehicle {
            current_cell <- my_grid[2, 2];
            location <- current_cell.location; // Đặt xe vào tâm ô grid
        }
    }
    
    // Khối cập nhật trạng thái môi trường (vật cản thay đổi theo thời gian)
    reflex update_environment {
        ask my_grid {
            if (type = 0 and flip(0.02)) { type <- 1; } 
            else if (type = 1 and flip(0.05)) { type <- 0; } 
        }
        target_cell.type <- 3; // Giữ ô đích không bị ghi đè
        
        // Cập nhật lại đồ thị đường đi từ các ô trống hiện tại
        list<my_grid> open_cells <- my_grid where (each.type != 1);
        road_graph <- grid_cells_to_graph(open_cells);
    }
}

// --- SPECIES XE (DI CHUYỂN VÀ TÌM ĐƯỜNG ĐỘNG) ---
species vehicle {
    my_grid current_cell; // Ô grid hiện tại xe đang đứng
    path my_path;         // Đường đi từ vị trí hiện tại đến đích
    reflex move_and_recalculate {
    	// 1. Xác định lại ô dưới chân xe (vị trí bắt đầu hiện tại)
        current_cell <- my_grid(location); 
        
        // 2. Tìm đường từ vị trí HIỆN TẠI đến ĐÍCH dựa trên đồ thị mới nhất
        my_path <- path_between(road_graph, current_cell, target_cell);
        
        // 3. Di chuyển bước tiếp theo dọc theo con đường vừa tìm được
        if (my_path != nil and not empty(my_path.segments)) {
            // Di chuyển đến ô tiếp theo trong lộ trình
            point next_location <- first(my_path.vertices); 
            location <- next_location;
            current_cell <- my_grid(location);
            write "move";
        }
    }

    aspect base {
        draw triangle(1.5) color: #magenta ;
    }
}

// --- GRID MÔ TRƯỜNG ---
grid my_grid width: grid_width height: grid_height neighbors: 4 {
    int type; // 0: trống, 1: vật cản, 3: đích
    
    aspect base {
        rgb cell_color <- #white;
        if (type = 1) { cell_color <- #black; }
        else if (type = 3) { cell_color <- #red; }
        draw shape color: cell_color border: #gray;
    }
}

experiment main_experiment type: gui {
    output {
        display main_display {
            grid my_grid border: #black;
            species vehicle aspect: base;
            agents "Labels" value: my_grid {
                draw string(type) at: location color: #black font: font("Arial", 14) anchor: #center;
            }
        }
    }
}