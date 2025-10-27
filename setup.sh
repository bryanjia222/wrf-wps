#!/bin/bash
# WRF Docker Setup Script

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}WRF Docker Setup Script${NC}"
echo "========================"

# Create directory structure
echo -e "\n${GREEN}Creating directory structure...${NC}"
mkdir -p scripts config WPS_GEOG data/{input,output} logs

# Check if files exist
echo -e "\n${GREEN}Checking required files...${NC}"

required_files=(
    "Dockerfile"
    "docker-compose.yml"
    "scripts/wrf_info.sh"
    "scripts/run.sh"
    "config/namelist.wps"
    "config/namelist.input"
)

missing_files=()
for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        missing_files+=("$file")
        echo -e "${RED}✗ Missing: $file${NC}"
    else
        echo -e "${GREEN}✓ Found: $file${NC}"
    fi
done

if [ ${#missing_files[@]} -ne 0 ]; then
    echo -e "\n${YELLOW}Please ensure all required files are in place before building.${NC}"
    exit 1
fi

# Set permissions
echo -e "\n${GREEN}Setting script permissions...${NC}"
chmod +x scripts/*.sh

# Download geographic data
echo -e "\n${YELLOW}WPS Geographic Data${NC}"

if [ ! -d "WPS_GEOG" ]; then
    mkdir -p WPS_GEOG
fi

if [ -z "$(ls -A WPS_GEOG 2>/dev/null)" ]; then
    echo "WPS_GEOG directory is empty."
else
    echo -e "${YELLOW}⚠ WPS_GEOG directory already contains files.${NC}"
fi

echo "Select geographic data resolution to download:"
echo "  1) Low resolution (~150MB)"
echo "  2) High resolution (~2.5GB)"
echo "  n) Skip download"
read -p "Enter your choice (1/2/n): " -n 1 -r
echo

case $REPLY in
    1)
        echo -e "${GREEN}Downloading low-resolution geographic data...${NC}"
        cd WPS_GEOG
        wget -c https://www2.mmm.ucar.edu/wrf/src/wps_files/geog_low_res_mandatory.tar.gz
        tar -xzf geog_low_res_mandatory.tar.gz
        rm -f geog_low_res_mandatory.tar.gz
        cd ..
        echo -e "${GREEN}✓ Low-resolution geographic data downloaded${NC}"
        ;;
    2)
        echo -e "${GREEN}Downloading high-resolution geographic data...${NC}"
        cd WPS_GEOG
        wget -c https://www2.mmm.ucar.edu/wrf/src/wps_files/geog_high_res_mandatory.tar.gz
        tar -xzf geog_high_res_mandatory.tar.gz
        rm -f geog_high_res_mandatory.tar.gz
        cd ..
        echo -e "${GREEN}✓ High-resolution geographic data downloaded${NC}"
        ;;
    [Nn])
        echo -e "${YELLOW}Skipped downloading geographic data.${NC}"
        ;;
    *)
        echo -e "${RED}Invalid input. Skipped.${NC}"
        ;;
esac

# Build Docker image
echo -e "\n${YELLOW}Docker Build${NC}"
read -p "Build Docker image now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}Building Docker image...${NC}"
    make build
    echo -e "${GREEN}✓ Docker image built successfully${NC}"
fi

# Final instructions
echo -e "\n${GREEN}Setup complete!${NC}"
echo -e "\nNext steps:"
echo "1. Place your input data in: ./data/input/"
echo "2. Modify configuration files in: ./config/"
echo "3. Start the container: docker compose up -d"
echo "4. Access the container: docker compose exec wrf-wps bash"
echo "5. Run WPS/WRF using the run.sh script"

echo -e "\n${YELLOW}Quick reference:${NC}"
echo "- WPS: docker compose exec wrf-wps run.sh wps"
echo "- WRF: docker compose exec wrf-wps run.sh wrf 8"
echo "- Info: docker compose exec wrf-wps wrf_info.sh"
