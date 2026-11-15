import sys,os
from PIL import Image,ImageDraw,ImageFont
T=sys.argv[1];O=sys.argv[2];os.makedirs(O,exist_ok=True)
F=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',22)
S=['Intact','Rotted','Destroyed']
for slot in ['Head','Torso','ArmL','ArmR','LegL','LegR']:
    ims=[[Image.open(f'{T}/{slot}_{st}_{k}.png') for k in range(3)] for st in S]
    w,h=ims[0][0].size;pad=8;top=34
    sheet=Image.new('RGB',(3*w+4*pad,3*(h+top)+pad),(18,14,22));d=ImageDraw.Draw(sheet)
    for r,st in enumerate(S):
        y=r*(h+top)+pad
        d.text((pad,y),f'{slot} - {st}',font=F,fill=(233,217,200))
        for k in range(3):sheet.paste(ims[r][k],(pad+k*(w+pad),y+top-6))
    sheet.save(f'{O}/{slot}.png')
a=Image.open(f'{T}/lineup_0.png');b=Image.open(f'{T}/lineup_1.png')
s=Image.new('RGB',(a.width,a.height*2+8),(18,14,22));s.paste(a,(0,0));s.paste(b,(0,a.height+8));s.save(f'{O}/lineup.png')
print('ok')
