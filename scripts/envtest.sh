#!/usr/bin/env bash
# 一键环境&库兼容性测试脚本（WRF 官方测试用例） https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compilation_tutorial.php#STEP4
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YEL='\033[1;33m'; NC='\033[0m'
fail() { echo -e "${RED}FAILED${NC}: $1"; exit 1; }
pass() { echo -e "${GREEN}SUCCESS${NC}: $1"; }

echo -e "${YEL}① 检查编译器...${NC}"
for c in gfortran gcc cpp; do
  command -v "$c" >/dev/null 2>&1 || fail "$c not found"
  echo " $(which $c)"
done
echo "gfortran version: $(gfortran -dumpversion)"
pass "编译器路径与版本"

echo -e "${YEL}② 准备目录...${NC}"
mkdir -p Build_WRF TESTS
cd TESTS

echo -e "${YEL}③ 下载并解压 Fortran/C 测试用例...${NC}"
FC_TAR=Fortran_C_tests.tar
[ -f $FC_TAR ] || \
  wget -q https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/$FC_TAR
tar -xf $FC_TAR

run_test() {
  local cmd="$1" expect="$2"
  echo -e "${YEL}   → $cmd${NC}"
  eval "$cmd" >/dev/null 2>&1 || fail "$cmd 编译失败"
  out=$(./a.out) && rm -f a.out *.o
  [[ "$out" == *"$expect"* ]] || fail "$cmd 结果异常"
  pass "$expect"
}

run_test "gfortran TEST_1_fortran_only_fixed.f"  "SUCCESS test 1"
run_test "gfortran TEST_2_fortran_only_free.f90" "SUCCESS test 2"
run_test "gcc TEST_3_c_only.c"                   "SUCCESS test 3"
run_test "bash -c 'gcc -c -m64 TEST_4_fortran+c_c.c && \
                  gfortran -c -m64 TEST_4_fortran+c_f.f90 && \
                  gfortran -m64 TEST_4_fortran+c_f.o TEST_4_fortran+c_c.o'" \
         "SUCCESS test 4"

for t in TEST_csh.csh TEST_perl.pl TEST_sh.sh; do
  echo -e "${YEL}   → ./$t${NC}"
  ./"$t" | grep -q SUCCESS || fail "$t 失败"
  pass "$t"
done
echo -e "${GREEN}系统环境测试全部通过${NC}"

echo -e "${YEL}④ （可选）NetCDF/MPI 兼容性测试...${NC}"
if [[ -n "${NETCDF:-}" ]]; then
  LIB_TAR=Fortran_C_NETCDF_MPI_tests.tar
  [ -f $LIB_TAR ] || \
    wget -q https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/$LIB_TAR
  tar -xf $LIB_TAR
  cp "${NETCDF}/include/netcdf.inc" .

  run_test "bash -c 'gfortran -c 01_fortran+c+netcdf_f.f && \
                     gcc     -c 01_fortran+c+netcdf_c.c && \
                     gfortran 01_fortran+c+netcdf_f.o 01_fortran+c+netcdf_c.o \
                              -L${NETCDF}/lib -lnetcdff -lnetcdf'" \
            "SUCCESS test 1"

  run_test "bash -c 'mpif90 -c 02_fortran+c+netcdf+mpi_f.f && \
                     mpicc  -c 02_fortran+c+netcdf+mpi_c.c && \
                     mpif90 02_fortran+c+netcdf+mpi_f.o 02_fortran+c+netcdf+mpi_c.o \
                            -L${NETCDF}/lib -lnetcdff -lnetcdf && \
                     mpirun -np 2 ./a.out'" \
            "SUCCESS test 2"

  echo -e "${GREEN}库兼容性测试全部通过${NC}"
else
  echo -e "${YEL}跳过：未设置 \$NETCDF 环境变量，未执行库兼容性测试${NC}"
fi

echo -e "${GREEN}✔ 所有请求的测试已完成${NC}"
