// Copyright © 2019-2023
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

`ifndef VORTEX_AFU_VH
	`define VORTEX_AFU_VH

	`define AFU_IMAGE_CMD_NONE         0
	`define AFU_IMAGE_CMD_MEM_READ     1
	`define AFU_IMAGE_CMD_MEM_WRITE    2
	`define AFU_IMAGE_CMD_RUN          3
	`define AFU_IMAGE_CMD_DCR_WRITE    4
	`define AFU_IMAGE_CMD_TERMINATE    7

	`define AFU_IMAGE_MMIO_BASE_ADDR   0xfff80000
	`define AFU_IMAGE_MMIO_CMD_TYPE     0  //0x00
	`define AFU_IMAGE_MMIO_CMD_ADDR     4  //0x04
	`define AFU_IMAGE_MMIO_CMD_DATA     8  //0x08
	`define AFU_IMAGE_MMIO_CMD_SIZE    12  //0x0C
	`define AFU_IMAGE_MMIO_DATA_READ   16  //0x10
	`define AFU_IMAGE_MMIO_STATUS      20  //0x14
	`define AFU_IMAGE_MMIO_DEV_CAPS    24  //0x18
	`define AFU_IMAGE_MMIO_DEV_CAPS_H  28  //0x1C
	`define AFU_IMAGE_MMIO_ISA_CAPS    32  //0x20
	`define AFU_IMAGE_MMIO_ISA_CAPS_H  36  //0x24
	`define AFU_IMAGE_MMIO_SCOPE_READ  40  //0x28
	`define AFU_IMAGE_MMIO_SCOPE_WRITE 44  //0x2C
	`define AFU_IMAGE_MMIO_VX_PC       48  //0x30
	`define AFU_IMAGE_MMIO_VX_INST     52  //0x34
	`define AFU_IMAGE_MMIO_DEBUG      128  //0x80

	`define AFU_IMAGE_STATE_IDLE      0
	`define AFU_IMAGE_STATE_MEM_READ  1
	`define AFU_IMAGE_STATE_MEM_WRITE 2
	`define AFU_IMAGE_STATE_RUN       3
	`define AFU_IMAGE_STATE_DCR       4
	`define AFU_IMAGE_STATE_BITS      3

	`include "VX_define.vh"

`endif // VORTEX_AFU_VH
