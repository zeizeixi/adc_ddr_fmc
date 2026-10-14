#ifndef FPGA_TRIGGER_V2_H
#define FPGA_TRIGGER_V2_H

/* Byte offsets from 0xD0000000. Use existing volatile 16-bit FMC accessors. */
#define FPGA_V2_EXPECTED_ID          0xADFCU
#define FPGA_V2_EXPECTED_VERSION     0x0200U
#define FPGA_V2_REG_TIME_MS          0x0008UL
#define FPGA_V2_REG_COMMAND          0x000AUL
#define FPGA_V2_REG_SAMPLES_L        0x0028UL
#define FPGA_V2_REG_SAMPLES_H        0x002AUL
#define FPGA_V2_REG_PRE_PERCENT      0x002CUL
#define FPGA_V2_REG_MODE             0x002EUL
#define FPGA_V2_REG_V_THRESHOLD      0x0030UL
#define FPGA_V2_REG_I_THRESHOLD      0x0032UL
#define FPGA_V2_REG_TRIGGER_ENABLE   0x0034UL
#define FPGA_V2_REG_TRIGGER_STATUS   0x0036UL
#define FPGA_V2_REG_ACTIVE_PRE_L     0x0038UL
#define FPGA_V2_REG_ACTIVE_PRE_H     0x003AUL
#define FPGA_V2_REG_RATE_L           0x003CUL
#define FPGA_V2_REG_RATE_H           0x003EUL
#define FPGA_V2_REG_LENGTH_MODE      0x0040UL
#define FPGA_V2_REG_V_COMPARE        0x0042UL
#define FPGA_V2_REG_I_COMPARE        0x0044UL

#define FPGA_V2_CMP_GE               0U
#define FPGA_V2_CMP_GT               1U
#define FPGA_V2_CMP_EQ               2U
#define FPGA_V2_CMP_LE               3U
#define FPGA_V2_CMP_LT               4U
#define FPGA_V2_MODE_MANUAL          0U
#define FPGA_V2_MODE_AUTO            1U
#define FPGA_V2_ENABLE_VOLTAGE       1U
#define FPGA_V2_ENABLE_CURRENT       2U

#define FPGA_V2_CMD_START            1U /* Legacy immediate: manual + PRE=0 only. */
#define FPGA_V2_CMD_READ_NEXT        2U
#define FPGA_V2_CMD_ACK              3U
#define FPGA_V2_CMD_RELEASE          4U
#define FPGA_V2_CMD_CLEAR_EVENTS     5U
#define FPGA_V2_CMD_ARM              6U
#define FPGA_V2_CMD_FORCE            7U
#define FPGA_V2_CMD_ABORT            8U

#define FPGA_V2_TRIG_ARMED           (1U << 0)
#define FPGA_V2_TRIG_HISTORY_READY   (1U << 1)
#define FPGA_V2_TRIG_TRIGGERED       (1U << 2)
#define FPGA_V2_TRIG_FINISHING       (1U << 3)
#define FPGA_V2_TRIG_ABORTED         (1U << 4)
#define FPGA_V2_REASON_VOLTAGE       (1U << 5) /* Reason valid after DONE. */
#define FPGA_V2_REASON_CURRENT       (1U << 6)
#define FPGA_V2_REASON_MANUAL        (1U << 7)

#define FPGA_V2_SAMPLE_RATE_HZ       100000000UL
#define FPGA_V2_MAX_SAMPLE_PAIRS     20000000UL
#endif
