/**************************************************************************
*  AW87319_Audio.c
*
*  Create Date :
*
*  Modify Date :
*
*  Create by   : AWINIC Technology CO., LTD
*
*  Version     : 0.9, 2016/02/15
*  Modify Date : 2018/06/15 - Luiz Paulo Damaceno, Incrase limits for Redmi 4X speaker (be louder and safe).
**************************************************************************/

#include <linux/i2c.h>
#include <linux/gpio.h>
#include <linux/interrupt.h>
#include <linux/delay.h>
#include <linux/irq.h>
#include <linux/firmware.h>
#include <linux/platform_device.h>

#include <linux/slab.h>
#include <linux/fs.h>
#include <linux/proc_fs.h>
#include <asm/uaccess.h>
#include <asm/io.h>
#include <linux/of_gpio.h>
#include <linux/init.h>
#include <linux/pci.h>
#include <linux/dma-mapping.h>
#include <linux/gameport.h>
#include <linux/moduleparam.h>
#include <linux/mutex.h>
#include <linux/wakelock.h>

//////////////////////////////////////////////////////////////////////////////////////////////////////////////
#define AW87319_I2C_NAME		"AW87319_PA"
#define AW87319_I2C_BUS		0
#define AW87319_I2C_ADDR	0x58
//////////////////////////////////////////////////////////////////////////////////////////////////////////////
static unsigned char AW87319_HW_ON(void);
static unsigned char AW87319_HW_OFF(void);
static unsigned char AW87319_SW_ON(void);
static unsigned char AW87319_SW_OFF(void);
unsigned char AW87319_Audio_Speaker(void);
unsigned char AW87319_Audio_Receiver(void);
unsigned char AW87319_Audio_OFF(void);
static ssize_t AW87319_get_reg(struct device* cd,struct device_attribute *attr, char* buf);
static ssize_t AW87319_set_reg(struct device* cd, struct device_attribute *attr,const char* buf, size_t len);
static ssize_t AW87319_set_swen(struct device* cd, struct device_attribute *attr,const char* buf, size_t len);
static ssize_t AW87319_get_swen(struct device* cd, struct device_attribute *attr, char* buf);
static ssize_t AW87319_set_hwen(struct device* cd, struct device_attribute *attr,const char* buf, size_t len);
static ssize_t AW87319_get_hwen(struct device* cd, struct device_attribute *attr, char* buf);

static DEVICE_ATTR(reg, 0660, AW87319_get_reg,  AW87319_set_reg);
static DEVICE_ATTR(swen, 0660, AW87319_get_swen,  AW87319_set_swen);
static DEVICE_ATTR(hwen, 0660, AW87319_get_hwen,  AW87319_set_hwen);

struct i2c_client *AW87319_pa_client;

//Read gpio pin from qcom,ext_pa_spk_aw87319_rst directly. 
int AW87319_rst;

struct pinctrl *AW87319ctrl = NULL;
struct pinctrl_state *AW87319_rst_high = NULL;
struct pinctrl_state *AW87319_rst_low = NULL;

char Spk_Pa_Flag[] = " ";
//////////////////////////////////////////////////////////////////////////////////////////////////////////////
// GPIO Control
//////////////////////////////////////////////////////////////////////////////////////////////////////////////

static void AW87319_pa_pwron(void)
{
	pr_debug("%s enter\n", __func__);
	gpio_direction_output(AW87319_rst,false);
	msleep(1);
	gpio_direction_output(AW87319_rst, true);
	msleep(10);
	pr_debug("%s out\n", __func__);
}

static void AW87319_pa_pwroff(void)
{
	pr_debug("%s enter\n", __func__);
	gpio_direction_output(AW87319_rst, false);
	msleep(1);
}


//////////////////////////////////////////////////////////////////////////////////////////////////////////////
// i2c write and read
//////////////////////////////////////////////////////////////////////////////////////////////////////////////
unsigned char I2C_write_reg(unsigned char addr, unsigned char reg_data)
{
	char ret;
	u8 wdbuf[512] = {0};

	struct i2c_msg msgs[] = {
		{
			.addr	= AW87319_pa_client->addr,
			.flags	= 0,
			.len	= 2,
			.buf	= wdbuf,
		},
	};

	wdbuf[0] = addr;
	wdbuf[1] = reg_data;

	if (NULL == AW87319_pa_client) {
		pr_err("msg %s AW87319_pa_client is NULL\n", __func__);
		return -EPERM;
	}

	ret = i2c_transfer(AW87319_pa_client->adapter, msgs, 1);
	if (ret < 0)
		pr_err("msg %s i2c read error: %d\n", __func__, ret);

    return ret;
}

unsigned char I2C_read_reg(unsigned char addr)
{
	unsigned char ret;
	u8 rdbuf[512] = {0};

	struct i2c_msg msgs[] = {
		{
			.addr	= AW87319_pa_client->addr,
			.flags	= 0,
			.len	= 1,
			.buf	= rdbuf,
		},
		{
			.addr	= AW87319_pa_client->addr,
			.flags	= I2C_M_RD,
			.len	= 1,
			.buf	= rdbuf,
		},
	};

	rdbuf[0] = addr;

	if (NULL == AW87319_pa_client) {
		pr_err("msg %s aw87319_pa_client is NULL\n", __func__);
		return -EPERM;
	}

	ret = i2c_transfer(AW87319_pa_client->adapter, msgs, 2);
	if (ret < 0)
		pr_err("msg %s i2c read error: %d\n", __func__, ret);

    return rdbuf[0];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// AW87319 PA
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
unsigned char AW87319_Audio_Receiver(void)
{
	AW87319_HW_ON();

	I2C_write_reg(0x05, 0x03);

	I2C_write_reg(0x01, 0x02);
	I2C_write_reg(0x01, 0x06);

	return 0;
}

unsigned char AW87319_Audio_Speaker(void)
{
	AW87319_HW_ON();
	I2C_write_reg(0x02, 0x36);		// BATSAFE -> Battery: 3.55V -> Boost 6V -> Software Enable
	I2C_write_reg(0x03, 0x07);		// BOV (boost output voltage) -> 8.5V (Maximum)
	I2C_write_reg(0x04, 0x07);		// BP (boost max coil peak current) ->  4A (Maximum)
	I2C_write_reg(0x05, 0x0F);		// Gain (Default 24dB), set it to 27dB push to the max
	I2C_write_reg(0x06, 0x0A);		// AGC3_Po (Default 0.8W for 8 Ohms and 1.07W for 6 Ohms), set it to 1.5W for 8 Ohms and 2W for 6 Ohms).
	I2C_write_reg(0x07, 0x52);		// AGC3 (doesn't should be toutched)
	I2C_write_reg(0x08, 0x64);		// AGC2 010: 1.8W@8Ω - 2.4W@6Ω, set it to 011: 011: 2.1W@8Ω 2.8W@6Ω and 0.32mS/dB
	I2C_write_reg(0x09, 0x02);		// AGC1 (doesn't should be toutched)
	I2C_write_reg(0x01, 0x03);              // CHIP disable; Class D Enable; Boost Enable
	I2C_write_reg(0x01, 0x07); 		// CHIP Enable; Class D Enable; Boost Enable

	return 0;
}

unsigned char AW87319_Audio_OFF(void)
{
	I2C_write_reg(0x01, 0x00);
	AW87319_HW_OFF();

	return 0;

}
unsigned char AW87319_SW_ON(void)
{
	unsigned char reg;
	reg = I2C_read_reg(0x01);
	reg |= 0x04;
	I2C_write_reg(0x01, reg);		// CHIP Enable; Class D Enable; Boost Enable

	return 0;
}

unsigned char AW87319_SW_OFF(void)
{
	unsigned char reg;
	reg = I2C_read_reg(0x01);
	reg &= 0xFB;
	I2C_write_reg(0x01, reg);		// CHIP Disable

	return 0;
}

unsigned char AW87319_HW_ON(void)
{
	AW87319_pa_pwron();
	I2C_write_reg(0x64, 0x2C);

	return 0;
}

unsigned char AW87319_HW_OFF(void)
{
	AW87319_pa_pwroff();

	return 0;
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
static ssize_t AW87319_get_reg(struct device* cd,struct device_attribute *attr, char* buf)
{
	unsigned char reg_val;
	ssize_t len = 0;
	u8 i;
	for(i=0;i<0x10;i++)
	{
		reg_val = I2C_read_reg(i);
		len += snprintf(buf+len, PAGE_SIZE-len, "reg%2X = 0x%2X, ", i,reg_val);
	}

	return len;
}

static ssize_t AW87319_set_reg(struct device* cd, struct device_attribute *attr, const char* buf, size_t len)
{
	unsigned int databuf[2];
	if(2 == sscanf(buf,"%x %x",&databuf[0], &databuf[1]))
	{
		I2C_write_reg(databuf[0],databuf[1]);
	}
	return len;
}

static ssize_t AW87319_get_swen(struct device* cd,struct device_attribute *attr, char* buf)
{
	ssize_t len = 0;
	len += snprintf(buf+len, PAGE_SIZE-len, "AW87319_SW_ON(void)\n");
	len += snprintf(buf+len, PAGE_SIZE-len, "echo 1 > swen\n");
	len += snprintf(buf+len, PAGE_SIZE-len, "\n");
	len += snprintf(buf+len, PAGE_SIZE-len, "AW87319_SW_OFF(void)\n");
	len += snprintf(buf+len, PAGE_SIZE-len, "echo 0 > swen\n");
	len += snprintf(buf+len, PAGE_SIZE-len, "\n");

	return len;
}

static ssize_t AW87319_set_swen(struct device* cd, struct device_attribute *attr, const char* buf, size_t len)
{
	unsigned int databuf[16];

	sscanf(buf,"%d",&databuf[0]);
	if(databuf[0] == 0) {		// OFF
		AW87319_SW_OFF();
	} else {					// ON
		AW87319_SW_ON();
	}

	return len;
}

static ssize_t AW87319_get_hwen(struct device* cd,struct device_attribute *attr, char* buf)
{
	ssize_t len = 0;
	len += snprintf(buf+len, PAGE_SIZE-len, "AW87319_HW_ON(void)\n");
	len += snprintf(buf+len, PAGE_SIZE-len, "echo 1 > hwen\n");
	len += snprintf(buf+len, PAGE_SIZE-len, "\n");
	len += snprintf(buf+len, PAGE_SIZE-len, "AW87319_HW_OFF(void)\n");
	len += snprintf(buf+len, PAGE_SIZE-len, "echo 0 > hwen\n");
	len += snprintf(buf+len, PAGE_SIZE-len, "\n");

	return len;
}

static ssize_t AW87319_set_hwen(struct device* cd, struct device_attribute *attr, const char* buf, size_t len)
{
	unsigned int databuf[16];

	sscanf(buf,"%d",&databuf[0]);
	if(databuf[0] == 0) {		// OFF
		AW87319_HW_OFF();
	} else {					// ON
		AW87319_HW_ON();
	}

	return len;
}


static int AW87319_create_sysfs(struct i2c_client *client)
{
	int err;
	struct device *dev = &(client->dev);

	err = device_create_file(dev, &dev_attr_reg);
	err = device_create_file(dev, &dev_attr_swen);
	err = device_create_file(dev, &dev_attr_hwen);
	return err;
}



////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
static int AW87319_i2c_probe(struct i2c_client *client, const struct i2c_device_id *id)
{
	unsigned char reg_value;
	unsigned char cnt = 5;
	int err = 0;

	pr_debug("%s Enter\n", __func__);


	if (!i2c_check_functionality(client->adapter, I2C_FUNC_I2C)) {
		err = -ENODEV;
		goto exit_check_functionality_failed;
	}

	if (client->dev.of_node != NULL)
		AW87319_rst = of_get_named_gpio(client->dev.of_node, "qcom,ext_pa_spk_aw87319_rst", 0);

	/* bitrvmpd: Fallback to the old method.
	 * There's no point on trying to make the above function work because
	 * santoni's board only has one gpio that enables the speaker.
	 * this gpio is 0x7c.
	 */
	if (AW87319_rst <= 0)
		AW87319_rst = 0x7c;

	if (AW87319_rst < 0) {
		err = -ENODEV;
		goto exit_gpio_get_failed;
	}
	if (gpio_request_one(AW87319_rst, GPIOF_DIR_OUT , "spk_enable")) {
		pr_err("%s: request spk_pa_gpio  fail!\n", __func__);
		goto exit_gpio_request_failed;
	}

	pr_debug("%s: aw87319_rst = %d \n", __func__, AW87319_rst);


	AW87319_pa_client = client;

	AW87319_HW_ON();
	msleep(10);

	while(cnt>0)
	{
		I2C_write_reg(0x64, 0x2C);
		
		reg_value = I2C_read_reg(0x00);
		printk("AW87319 CHIPID=0x%2x\n", reg_value);
		if(reg_value == 0x9B)
		{
			break;
		}
		cnt --;
		msleep(10);
	}
	if(!cnt)
	{
		err = -ENODEV;
		
		AW87319_HW_OFF();
		strncpy(Spk_Pa_Flag, "S88537A12", 9);
		pr_err("%s:can not find AW87319, board  is S88537A12\n!", __func__);

		goto exit_create_singlethread;
	}

	AW87319_create_sysfs(client);
	AW87319_HW_OFF();

	return 0;

exit_create_singlethread:
	AW87319_pa_client = NULL;
exit_gpio_request_failed:
	gpio_free(AW87319_rst);
exit_gpio_get_failed:
exit_check_functionality_failed:
	return err;
}

static int AW87319_i2c_remove(struct i2c_client *client)
{
	AW87319_pa_client = NULL;
	return 0;
}

static const struct i2c_device_id AW87319_i2c_id[] = {
	{AW87319_I2C_NAME, 0},
	{},
};

MODULE_DEVICE_TABLE(i2c, AW87319_i2c_id);

#ifdef CONFIG_OF
static const struct of_device_id extpa_of_match[] = {
	{.compatible = "awinic,aw87319_pa"},
	{},
};
#endif

static struct i2c_driver AW87319_i2c_driver = {
        .driver = {
                .name   = AW87319_I2C_NAME,
				.owner = THIS_MODULE,
#ifdef CONFIG_OF
				.of_match_table = extpa_of_match,
#endif
},

        .probe          = AW87319_i2c_probe,
        .remove         = AW87319_i2c_remove,
        .id_table       = AW87319_i2c_id,
};

static int __init AW87319_pa_init(void) {
	int ret;
	printk("AW87319 PA Init\n");

	ret = i2c_add_driver(&AW87319_i2c_driver);
	if (ret) {
		printk("[%s] failed to register AW87319 i2c driver.\n", __func__);
		return ret;
	} else {
		printk("[%s] Success to register AW87319 i2c driver.\n", __func__);
	}
	
	return 0;
}

static void __exit AW87319_pa_exit(void) {
	printk("AW87319 PA Exit\n");
	i2c_del_driver(&AW87319_i2c_driver);
}

module_init(AW87319_pa_init);
module_exit(AW87319_pa_exit);

MODULE_AUTHOR("<liweilei@awinic.com.cn>");
MODULE_DESCRIPTION("AWINIC AW87319 PA driver");
MODULE_LICENSE("GPL");

