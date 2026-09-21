package VX_fpu_pkg;
typedef struct packed {
    logic is_normal;
    logic is_zero;
    logic is_subnormal;
    logic is_inf;
    logic is_nan;
    logic is_quiet;
    logic is_signaling;    
} fclass_t;
typedef struct packed {
    logic NV;  
    logic DZ;  
    logic OF;  
    logic UF;  
    logic NX;  
} fflags_t;
endpackage
