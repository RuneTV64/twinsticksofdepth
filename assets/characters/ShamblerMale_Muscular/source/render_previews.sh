#!/bin/bash
# usage: run.sh cfg.json WxH
cd "$(dirname "$0")"
G=../godot
timeout 120 $G --headless --import . >/dev/null 2>&1
CFG=$(realpath "$1") timeout 90 xvfb-run -a -s "-screen 0 1600x900x24" $G --rendering-driver opengl3 --resolution $2 res://render.tscn 2>&1 | grep -E "ERROR|SCRIPT|SHADER|error"| grep -v ALSA | grep -v "ERR_CANT_OPEN" | head -30
#!/bin/bash
cd "$(dirname "$0")"
./run.sh pa_inside.json 370x300
for n in cs_r ch_r cs_d ch_d cfl; do ./run.sh $n.json 200x200; done
./run.sh cf_r.json 200x260
./run.sh cf_d.json 200x260
./run.sh cdp.json 200x260
./run.sh pa_torso.json 330x250
./run.sh pa_fore.json 150x150
./run.sh pa_shin.json 150x150
./run.sh pa_hum.json 150x150
./run.sh ps_Head_Intact.json 100x125
./run.sh ps_Head_Rotted.json 100x125
./run.sh ps_Head_Destroyed.json 100x125
./run.sh ps_Torso_Intact.json 100x125
./run.sh ps_Torso_Rotted.json 100x125
./run.sh ps_Torso_Destroyed.json 100x125
./run.sh ps_ArmL_Intact.json 100x125
./run.sh ps_ArmL_Rotted.json 100x125
./run.sh ps_ArmL_Destroyed.json 100x125
./run.sh ps_ArmR_Intact.json 100x125
./run.sh ps_ArmR_Rotted.json 100x125
./run.sh ps_ArmR_Destroyed.json 100x125
./run.sh ps_LegL_Intact.json 100x125
./run.sh ps_LegL_Rotted.json 100x125
./run.sh ps_LegL_Destroyed.json 100x125
./run.sh ps_LegR_Intact.json 100x125
./run.sh ps_LegR_Rotted.json 100x125
./run.sh ps_LegR_Destroyed.json 100x125
./run.sh pd_0.json 100x125
./run.sh pd_1.json 100x125
./run.sh pd_2.json 100x125
./run.sh pd_3.json 100x125
./run.sh pm_mix.json 250x150
for n in zd_stages zd_wounds zd_crowd; do ./run.sh $n.json $(cat $n.size); done
./run.sh pb_full.json 220x150
./run.sh pb_close.json 400x140
for n in $(cat hd_jobs.txt); do ./run.sh $n.json 150x150; done
./run.sh hdc_full.json 170x200
echo renders done
#!/bin/bash
cd "$(dirname "$0")"
for n in zd_stages zd_wounds zd_crowd zd_tones0 zd_tones1 zd_tones2 zd_tones3 zd_tones4 zd_tonesb0 zd_tonesb1 zd_tonesb2 zd_tonesb3 zd_tonesb4 zd_grime_light zd_grime_deep; do ./run.sh $n.json $(cat $n.size); done
for k in porc maho honey; do ./run.sh turn_${k}_alive.json 60x150; ./run.sh turn_${k}_dead.json 250x150; done
echo renders done
