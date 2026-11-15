import json
from PIL import Image, ImageDraw, ImageFont
BG=(18,14,22); BAND=(24,19,30); TX=(233,217,200); MU=(168,149,143); AC=(217,162,115)
FB=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',20)
FS=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',16)
import sys
TONES=['Porcelain','Cream','Fawn','Umber','Mahogany','Ebony','Golden','Copper','Bronze','Wheat','Honey','Almond','Sand','Caramel','Chestnut']
IDS=[int(x) for x in sys.argv[1].split(',')] if len(sys.argv)>1 else [0,1,2]
GROUP=sys.argv[2] if len(sys.argv)>2 else 'european'; VAR=['Freckles','Clean shaven','Hairy','Old','Vitiligo']; HN=['blond','ginger','brown','dark','grey']
HAIRS={int(k):v for k,v in json.load(open('hairs.json')).items()}
def crop(im, rows=None):
    bg=im.getpixel((0,0)); w,h=im.size; px=im.load()
    rr=[y for y in range(h) if any(px[x,y]!=bg for x in range(0,w,1))]
    return (rr[0],rr[-1]) if rr else (0,h-1)
def label(d,cx,y,a,b):
    for t,f,c,dy in [(a,FB,TX,4),(b,FS,MU,26)]:
        tw=d.textlength(t,font=f); d.text((cx-tw/2,y+dy),t,font=f,fill=c)
def grid(pre, k, cam, gap, out, title, views, crop_top=True):
    # one row per tone; each row has the views side by side
    rows=[]
    for t in IDS:
        ims=[Image.open(f'{pre}{t}_{v}.png').convert('RGB') for v in views]
        ys=[crop(i) for i in ims]; y0=min(a for a,b in ys)-2; y1=max(b for a,b in ys)+3
        if not crop_top: y0=0
        ims=[i.crop((0,max(0,y0),i.width,min(i.height,y1))) for i in ims]
        ppm=Image.open(f'{pre}{t}_0.png').height/cam*k
        rows.append((t,[i.resize((i.width*k,i.height*k),Image.NEAREST) for i in ims],ppm))
    vw=rows[0][1][0].width; W=vw*len(views)+8*(len(views)-1); top=40; tl=30; lab=46
    H=top+sum(tl+r[1][0].height+lab for r in rows)+8
    s=Image.new('RGB',(W,H),BG); d=ImageDraw.Draw(s); d.text((8,10),title,font=FB,fill=TX)
    y=top
    for t,ims,ppm in rows:
        d.text((8,y+4),f'{TONES[t]}  (skin_tone {t})',font=FB,fill=AC); y+=tl
        for j,im in enumerate(ims):
            x0=j*(vw+8); s.paste(im,(x0,y))
        hh=ims[0].height
        d.rectangle((0,y+hh,W,y+hh+lab),fill=BAND)
        for j in range(len(ims)):
            x0=j*(vw+8)
            zs=json.load(open(f'{pre}{t}.json'))['zombies']   # what each column actually shows
            for v,z in enumerate(zs):
                cx=x0+vw/2+(v-(len(zs)-1)/2)*gap*ppm
                label(d,cx,y+hh,VAR[z['params']['variant']],f"{HN[z['params']['hair_color']]} hair")
        y+=hh+lab
    s.save(out); print(out,s.size)
T={'european':'European','african':'African','latin':'Latin American','asian':'Asian','mideast_southasia':'Middle Eastern & South Asian'}.get(GROUP,GROUP.capitalize())
grid('fin',3,2.05,0.62,f'out/living_{GROUP}_grid.png',f'{T} skin tones: 5 looks each, front and back',[0,1])
grid('cu',2,0.75,0.62,f'out/living_{GROUP}_closeup.png',f'{T} skin tones, close up: face, chest and arms',[0],crop_top=False)
grid('cu',2,0.75,0.62,f'out/living_{GROUP}_closeup_back.png',f'{T} skin tones, close up from behind',[1],crop_top=False)
