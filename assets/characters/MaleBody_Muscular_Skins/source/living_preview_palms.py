# Palm strips: python3 compose_palms.py <group> <title> <tone,tone,...> [tone:note ...]
import sys
from PIL import Image, ImageDraw, ImageFont
BG=(18,14,22); BAND=(24,19,30); TX=(233,217,200); MU=(168,149,143)
FB=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',20); FS=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',16)
TONES=['Porcelain','Cream','Fawn','Umber','Mahogany','Ebony','Golden','Copper','Bronze','Wheat','Honey','Almond','Sand','Caramel','Chestnut']
group,title,ids=sys.argv[1],sys.argv[2],[int(x) for x in sys.argv[3].split(',')]
notes=dict(a.split(':',1) for a in sys.argv[4:])
ims=[Image.open(f'palm{t}_0.png').convert('RGB').resize((360,360),Image.NEAREST) for t in ids]
W=360*len(ids)+8*(len(ids)-1); s=Image.new('RGB',(W,450),BG); d=ImageDraw.Draw(s)
d.text((8,10),title,font=FB,fill=TX)
for i,(t,im) in enumerate(zip(ids,ims)):
    x=i*368; s.paste(im,(x,40)); d.rectangle((x,400,x+360,450),fill=BAND)
    for txt,f,c,dy in [(TONES[t],FB,TX,4),(f'skin_tone {t}'+(': '+notes[str(t)] if str(t) in notes else ''),FS,MU,26)]:
        tw=d.textlength(txt,font=f); d.text((x+180-tw/2,400+dy),txt,font=f,fill=c)
s.save(f'out/living_{group}_palms.png'); print(group,s.size)
