from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
import math, subprocess, textwrap, os
ROOT=Path(__file__).resolve().parent
SCREENS=Path(os.environ.get('TRIP_TUTORIAL_SCREENS', ROOT/'screens'))
OUT=(ROOT.parent/'App'/'Resources' if ROOT.name=='scripts' else ROOT)/'Trip_Info_Quick_Tour.mp4'
OUT.parent.mkdir(parents=True, exist_ok=True)
W,H=600,1400
FPS=24
BLUE='#187CF5'; INK='#192637'
def font(n,bold=False):
    return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans'+('-Bold' if bold else '')+'.ttf',n)
# Exactly 15 six-second chapters, matching the in-app chapter links.
chapters=[
 ('Home',['00-home'], 'Choose Home and Destination. Edit either currency amount.', 'Examples shown · rates and weather are sample values', (.28,.38)),
 ('Multiple prices',['01-currency','02-multiple'], 'Add each price. Check + or −, then use the total.', 'Example: ¥500 + ¥400 + ¥650 = ¥1,550', (.43,.48)),
 ('Camera and photos',['03-camera','04-prices'], 'Point at marked prices. Review or correct every result.', 'Generated camera scene · check the From currency.', (.50,.64)),
 ('Save a conversion',['05-save','05-save-note'], 'Keep the photo, enter a useful note, then tap Save.', 'Example: Coffee at the station cafe', (.48,.64)),
 ('Open a saved entry',['06-saved','06-saved-detail'], 'Open Saved and select the entry to revisit its photo and note.', 'The original amount and dated estimate stay together.', (.40,.32)),
 ('Units',['07-units'], 'Choose units. Edit either value, add a note, and Save.', 'Example: suitcase · 10 kg ≈ 22.05 lb', (.38,.45)),
 ('World Time',['08-world-now','08-world-compare','08-world-now'], 'Move the slider to compare. Return to now restores live clocks.', 'Zero is centered. Every displayed city shifts together.', (.54,.77)),
 ('Translate',['09-translate','09-translate-result'], 'Choose languages, enter text or a photo, then Translate.', 'Review the result, add a note, and tap Save.', (.46,.52)),
 ('My Trip: hotel',['10-hotel','10-hotel-notes'], 'Enter hotel, booking, address, dates, time zones, and a note.', 'Example booking shown · review details, then Save.', (.44,.38)),
 ('My Trip: flight',['11-flight','11-flight-notes'], 'Enter airline, flight number, route, and local departure/arrival times.', 'Choose a time zone for each city, then Save.', (.50,.48)),
 ('My Trip: transport',['12-transport','12-transport-notes','12-trip-list'], 'Add train or bus details, booking, dates, and a note.', 'Your saved journeys appear together in My Trip.', (.42,.38)),
 ('Reorder cities and tabs',['13-reorder'], 'Hold an extra city or a bottom tab. Drag it, then tap Done.', 'Home and Destination remain the two main clock cards.', (.50,.94)),
 ('Weather',['14-weather'], 'Refresh while connected. Check observed and retrieved times.', 'Saved weather remains available offline and may be older.', (.57,.63)),
 ('Settings',['15-settings','15-settings-help'], 'Choose appearance and clock options. Enable Lock app if wanted.', 'Help, rates, privacy, credits, and version are below.', (.52,.43)),
 ('Before you go offline',['16-offline'], 'Refresh rates and weather. Prepare your translation languages online.', 'Saved entries, units, clocks, and this tutorial work offline.', (.48,.55)),
]
images={name:Image.open(SCREENS/(name+'.png')).convert('RGB') for _,names,*_ in chapters for name in names}
def draw_hand(im,x,y,t):
    d=ImageDraw.Draw(im)
    radius=16+3*math.sin(t*5)
    d.ellipse((x-radius,y-radius,x+radius,y+radius),outline=BLUE,width=3)
    # Clear outlined pointing finger, with its fingertip at the target.
    points=[(x-7,y+40),(x-7,y+7),(x-5,y+1),(x,y-2),(x+5,y+1),(x+7,y+7),(x+7,y+26),(x+13,y+20),(x+18,y+21),(x+22,y+26),(x+28,y+23),(x+34,y+29),(x+39,y+29),(x+44,y+36),(x+43,y+60),(x+32,y+78),(x+4,y+78),(x-15,y+53),(x-16,y+44),(x-11,y+40)]
    d.polygon(points,fill='white',outline=INK,width=3)
    d.line([(x+7,y+27),(x+7,y+47)],fill=INK,width=2)
    d.line([(x+22,y+29),(x+22,y+48)],fill=INK,width=2)
    d.line([(x+34,y+33),(x+34,y+48)],fill=INK,width=2)
process=subprocess.Popen(['ffmpeg','-y','-v','error','-f','rawvideo','-pix_fmt','rgb24','-s',f'{W}x{H}','-r',str(FPS),'-i','-','-an','-c:v','libx264','-preset','fast','-crf','23','-pix_fmt','yuv420p','-movflags','+faststart',str(OUT)],stdin=subprocess.PIPE)
contact=[]
for frame in range(90*FPS):
    t=frame/FPS; index=int(t//6); local=t%6
    title,names,body,detail,target=chapters[index]
    name=names[min(len(names)-1,int(local/6*len(names)))]
    original=images[name]
    # Video framing removes the empty OS status-bar area. Camera chapters zoom
    # to the working controls and sample scene; simulator-only errors are below.
    bottom=2200 if name in ['03-camera','04-prices'] else original.height-60
    original=original.crop((0,140,original.width,bottom))
    screen=original.copy();screen.thumbnail((W-24,1100),Image.Resampling.LANCZOS)
    left=(W-screen.width)//2;top=100
    im=Image.new('RGB',(W,H),'#F6F8FB');im.paste(screen,(left,top))
    d=ImageDraw.Draw(im)
    d.text((20,18),f'{index+1:02d} / 15',font=font(16),fill=BLUE)
    d.text((20,43),title,font=font(25,True),fill=INK)
    d.text((W-20,20),'Example data · silent',font=font(14),fill='#607088',anchor='ra')
    y=1220
    for line in textwrap.wrap(body,width=49):
        d.text((20,y),line,font=font(20,True),fill=INK);y+=29
    for line in textwrap.wrap(detail,width=57):
        d.text((20,y+8),line,font=font(17),fill='#59697D');y+=25
    d.rectangle((20,H-15,W-20,H-10),fill='#DCE4EF')
    d.rectangle((20,H-15,20+(W-40)*t/90,H-10),fill=BLUE)
    x=left+screen.width*target[0];y=top+screen.height*target[1]
    if local>.5:draw_hand(im,x,y,local)
    if frame%144==80:contact.append(im.resize((180,420)))
    process.stdin.write(im.tobytes())
process.stdin.close()
if process.wait():raise SystemExit('Video encoding failed')
sheet=Image.new('RGB',(5*180,3*420),'white')
for i,im in enumerate(contact):sheet.paste(im,((i%5)*180,(i//5)*420))
sheet.save(ROOT/'tutorial-contact.jpg',quality=90)
print(OUT)
