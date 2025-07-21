#!/bin/bash
# WRF/WPS Run Script

# Default number of processors
DEFAULT_NPROC=4

# Function to print usage
print_usage() {
    echo "Usage: run.sh [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  wrf [nproc]     - Run wrf.exe with specified number of processors (default: $DEFAULT_NPROC)"
    echo "  real [nproc]    - Run real.exe with specified number of processors (default: $DEFAULT_NPROC)"
    echo "  wps             - Run all WPS components (geogrid, ungrib, metgrid)"
    echo "  geogrid         - Run only geogrid.exe"
    echo "  ungrib          - Run only ungrib.exe"
    echo "  metgrid         - Run only metgrid.exe"
    echo ""
    echo "Examples:"
    echo "  run.sh wrf 8    - Run WRF with 8 processors"
    echo "  run.sh wps      - Run complete WPS workflow"
    echo "  run.sh real     - Run real.exe with default processors"
}

# Function to check if executable exists
check_executable() {
    if [ ! -f "$1" ]; then
        echo "Error: $1 not found!"
        echo "Please ensure WRF/WPS is properly compiled."
        exit 1
    fi
}

# Main logic
case "$1" in
    wrf)
        cd $WRF_DIR/run
        check_executable "./wrf.exe"
        NPROC=${2:-$DEFAULT_NPROC}
        echo "Running WRF with $NPROC processors..."
        mpirun -np $NPROC ./wrf.exe
        ;;
        
    real)
        cd $WRF_DIR/run
        check_executable "./real.exe"
        NPROC=${2:-$DEFAULT_NPROC}
        echo "Running real.exe with $NPROC processors..."
        mpirun -np $NPROC ./real.exe
        ;;
        
    wps)
        cd $WPS_DIR
        echo "Running WPS workflow..."
        
        # Run geogrid
        if [ -f "./geogrid.exe" ]; then
            echo "Step 1/3: Running geogrid.exe..."
            ./geogrid.exe
            if [ $? -ne 0 ]; then
                echo "Error: geogrid.exe failed!"
                exit 1
            fi
        else
            echo "Warning: geogrid.exe not found, skipping..."
        fi
        
        # Run ungrib
        if [ -f "./ungrib.exe" ]; then
            echo "Step 2/3: Running ungrib.exe..."
            ./ungrib.exe
            if [ $? -ne 0 ]; then
                echo "Error: ungrib.exe failed!"
                exit 1
            fi
        else
            echo "Warning: ungrib.exe not found, skipping..."
        fi
        
        # Run metgrid
        if [ -f "./metgrid.exe" ]; then
            echo "Step 3/3: Running metgrid.exe..."
            ./metgrid.exe
            if [ $? -ne 0 ]; then
                echo "Error: metgrid.exe failed!"
                exit 1
            fi
        else
            echo "Warning: metgrid.exe not found, skipping..."
        fi
        
        echo "WPS workflow completed!"
        ;;
        
    geogrid)
        cd $WPS_DIR
        check_executable "./geogrid.exe"
        echo "Running geogrid.exe..."
        ./geogrid.exe
        ;;
        
    ungrib)
        cd $WPS_DIR
        check_executable "./ungrib.exe"
        echo "Running ungrib.exe..."
        ./ungrib.exe
        ;;
        
    metgrid)
        cd $WPS_DIR
        check_executable "./metgrid.exe"
        echo "Running metgrid.exe..."
        ./metgrid.exe
        ;;
        
    *)
        print_usage
        exit 1
        ;;
esac
