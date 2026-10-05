from PIL import Image, ImageDraw, ImageFont, ImageOps
from pathlib import Path
import math, subprocess
ROOT=Path(__file__).resolve().parent
ASSETS=ROOT/'help-tour-assets'
OUTPUT=ROOT.parent/'App'/'Resources' if ROOT.name=='scripts' else ROOT
OUTPUT.mkdir(parents=True,exist_ok=True)
W,H=600,1068
BLUE='#287AF5';INK='#172336';GREY='#68788D';LIGHT='#F1F4F9'
cafe=Image.open(ASSETS/'cafe-menu.jpg').convert('RGB')
luggage=Image.open(ASSETS/'luggage-scale.jpg').convert('RGB')
def font(n,b=False):return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans'+('-Bold' if b else '')+'.ttf',n)
scenes=[
 ('Home','Choose cities and edit either amount.','Both values update using dated rates.'),
 ('Add multiple prices','Enter prices; tap + / − to change signs.','Use total sends the result to Currency.'),
 ('Photo prices','Choose Camera or Photo; capture a menu.','Review each detected price before saving.'),
 ('Save conversion','Keep the reference photo and add a note.','Tap Save, then open Saved to revisit it.'),
 ('Unit converter','Choose a photo; select its measurement.','Review units and values, add a note, Save.'),
 ('World Time','Drag the slider to compare every city.','Return to now restores live clocks.'),
 ('Translate','Choose languages, enter text and Translate.','Review the result; add a note and Save.'),
 ('My Trip · Hotel','Fill hotel, booking, address and dates.','Choose local time zones, add notes, Save.'),
 ('My Trip · Flight','Fill operator, flight, route and dates.','Choose each city’s time zone, then Save.'),
 ('My Trip · Transport','Choose Transport for trains or buses.','Fill the journey details, then Save.'),
 ('Make it yours','Hold and drag extra cities or bottom tabs.','Tap Done to keep your chosen order.'),
 ('Weather','Choose a city; Refresh while connected.','Check retrieved time and forecast time zone.'),
 ('Settings','Choose a theme and your clock options.','Enable Lock app if wanted, then Done.'),
 ('Before you leave','Refresh rates/weather; download languages.','Saved entries and this tour work offline.')]
DURATION=84
p=subprocess.Popen(['ffmpeg','-y','-loglevel','error','-f','rawvideo','-pix_fmt','rgb24','-s',f'{W}x{H}','-r','24','-i','-','-an','-c:v','libx264','-preset','fast','-crf','24','-pix_fmt','yuv420p','-movflags','+faststart',str(OUTPUT/'Trip_Info_Quick_Tour.mp4')],stdin=subprocess.PIPE)
samples=[]
for frame in range(DURATION*24):
 t=frame/24;scene=int(t/6);local=t%6
 im=Image.new('RGB',(W,H),'#F9FBFF');d=ImageDraw.Draw(im)
 def text(x,y,s,n=22,b=False,c=INK):d.text((x,y),s,font=font(n,b),fill=c)
 def center(y,s,n=22,b=False,c=INK):d.text((W/2,y),s,font=font(n,b),fill=c,anchor='mt')
 def box(x,y,w,h,fill=LIGHT):d.rounded_rectangle((x,y,x+w,y+h),radius=15,fill=fill)
 def hand(x,y):
  r=14+6*math.sin(local*5);d.ellipse((x-r,y-r,x+r,y+r),outline=BLUE,width=3)
  tile=Image.new('RGBA',(180,210));hd=ImageDraw.Draw(tile)
  pts=[(0,0),(8,0),(12,5),(12,37),(18,34),(25,37),(26,42),(33,40),(41,43),(41,48),(47,47),(54,51),(54,69),(47,91),(42,95),(0,95),(-8,90),(-24,65),(-25,55),(-19,50),(-13,51),(-2,63),(-2,9),(0,0)]
  pts=[((px+30)*2,(py+3)*2) for px,py in pts];hd.polygon(pts,fill='white');hd.line(pts,fill=INK,width=5,joint='curve')
  for px,py in [(12,39),(26,44),(41,50)]:hd.line(((px+30)*2,(py+3)*2,(px+30)*2,(py+21)*2),fill=INK,width=3)
  tile=tile.resize((90,105),Image.Resampling.LANCZOS);im.paste(tile,(int(x-30),int(y-3)),tile)
 def field(y,label,value,active=False):
  box(65,y,470,53);text(81,y+7,label,13,c=GREY);text(81,y+25,value,18,True)
  if active:d.rounded_rectangle((65,y,535,y+53),radius=15,outline=BLUE,width=2)
 def button(y,label):box(65,y,470,50,BLUE);center(y+14,label,20,True,'white')
 def photo(x,y,w,h,source=cafe):
  preview=ImageOps.contain(source,(w,h),method=Image.Resampling.LANCZOS)
  box(x,y,w,h,'#ECE9E3');im.paste(preview,(x+(w-preview.width)//2,y+(h-preview.height)//2))
 text(32,30,'TRIP INFO',17,True,BLUE);text(388,30,f'STEP {scene+1} OF 14',15,True,GREY)
 center(84,scenes[scene][0],28,True)
 box(36,150,528,650,'#DDE5F0');box(42,144,516,650,'white')
 text(65,170,scenes[scene][0],22,True);text(477,173,'Save' if scene in [3,6,7,8,9] else 'Done',16,True,BLUE)
 if scene==0:
  for x,role,city,time in [(65,'Home','Los Angeles','1:08 PM'),(310,'Destination','Tokyo','5:08 AM')]:
   box(x,226,225,158,'#EAF4ED' if role=='Home' else '#EAF1FC');text(x+17,244,role,16,c=GREY);text(x+17,279,city,21,True);text(x+17,329,time,25,True)
  field(414,'From currency','USD · United States');field(479,'To currency','JPY · Japan')
  field(544,'From amount','100.00',local<3);field(609,'To amount','≈ 15,792')
  text(80,684,'Reference rates as of Oct 5, 2026',17,c=GREY);text(80,715,'Example rates · final charges may differ',15,c=GREY)
  hand(192,568 if local<3 else 657)
 elif scene==1:
  field(225,'Currency pair','JPY → USD')
  for i,(sign,item,value) in enumerate([('+','Coffee','500'),('+','Cake','650'),('−','Discount','100')]):
   box(65,304+i*78,470,64);text(85,323+i*78,sign,25,True,BLUE);text(133,324+i*78,item,20);text(435,322+i*78,value,22,True)
  field(556,'Total','¥1,050 → ≈ $6.65');button(644,'Use total');hand(461,477 if local<3 else 667)
 elif scene==2:
  field(221,'From → To','JPY Japan → USD United States')
  box(65,290,225,52,BLUE);box(310,290,225,52,'#EAF1FC');text(83,305,'✓ Live Camera',20,True,'white');text(385,305,'Photo',20,True,BLUE)
  photo(65,357,470,270)
  d.ellipse((275,568,325,618),fill='white',outline=INK,width=2);d.rounded_rectangle((287,585,313,603),radius=3,fill=INK);d.ellipse((296,589,306,599),fill='white')
  field(645,'Recognized price · tap to correct','¥500 → ≈ $3.17',local>3);button(715,'Save ¥500')
  if local<1.6:hand(185,313)
  elif local<3.3:hand(300,593)
  else:hand(300,741)
 elif scene==3:
  field(221,'Conversion preview','¥500 JPY → ≈ $3.17 USD');photo(65,289,470,230)
  field(541,'Note','Coffee at the station café',local<3)
  field(608,'Reference photo','Café menu attached');field(675,'Rate date','Oct 5, 2026 · original estimate')
  if local<3:hand(400,566)
  else:hand(496,185)
  if local>4.6:center(746,'✓ Saved on this device',18,True,BLUE)
 elif scene==4:
  photo(65,220,470,154,luggage)
  field(389,'Category / input','Weight · Photo selected ✓')
  field(453,'From unit and value','10.0 Kilograms (kg)',local<3)
  field(517,'To unit and value','22.0462 Pounds (lb)')
  field(581,'Note','Checked suitcase before departure')
  button(653,'Save conversion');hand(300,478 if local<3 else 678)
 elif scene==5:
  off=round(4*max(0,min(1,(local-1)/2))) if local<4.5 else 0
  field(225,'Los Angeles · Home',f'{1+off}:08 PM');field(294,'Tokyo · Destination',f'{5+off}:08 AM · Tomorrow');field(363,'London',f'{(9+off-1)%12+1}:08 '+('PM' if off<3 else 'AM'));field(432,'Melbourne',f'{7+off}:08 AM · Tomorrow')
  text(80,526,'Compare city times',22,True);text(371,569,'Return to now',17,c=BLUE)
  d.line((85,628,515,628),fill='#D3DCE8',width=8);x=300+off*8;d.line((85,628,x,628),fill=BLUE,width=8);d.ellipse((x-13,615,x+13,641),fill=BLUE)
  center(675,'Now · 0 hours' if off==0 else f'+{off} hours from now',20,c=GREY)
  hand(x,628) if local<4.5 else hand(428,577)
 elif scene==6:
  field(221,'From language','English (General)');field(285,'To language','Spanish');field(349,'Text','A coffee, please.',local<2)
  button(415,'Translate');field(485,'Translation','Un café, por favor.');field(549,'Note','Ordering at the café');photo(65,616,174,116);text(257,642,'Reference photo',17,True);text(257,675,'Café menu attached',16,c=GREY)
  if local<2:hand(337,374)
  elif local<4:hand(300,440)
  else:hand(497,185)
 elif scene in [7,8,9]:
  if scene==7:fields=[('Type','Hotel'),('Hotel name','Example Tokyo Hotel'),('Booking reference','DEMO-HOTEL-01'),('Hotel address','1-2-3 Example St, Tokyo'),('Check-in','Oct 12, 2026 · 3:00 PM'),('Check-in city','Tokyo · Asia/Tokyo'),('Check-out','Oct 15, 2026 · 11:00 AM'),('Check-out city','Tokyo · Asia/Tokyo'),('Notes','Late check-in requested')]
  elif scene==8:fields=[('Type','Flight'),('Airline / operator','Example Air'),('Flight number','DEMO101'),('From','Los Angeles (LAX)'),('To','Tokyo (HND)'),('Departure / city','Oct 11 · 12:00 PM · Los Angeles'),('Arrival / city','Oct 12 · 4:00 PM · Tokyo'),('Notes','Check baggage allowance')]
  else:fields=[('Type','Transport'),('Airline / operator','Example Rail'),('Booking reference','DEMO-TRAIN-01'),('From','Tokyo Station'),('To','Kyoto Station'),('Departure / city','Oct 15 · 10:00 AM · Tokyo'),('Arrival / city','Oct 15 · 12:15 PM · Kyoto'),('Notes','Seat 8A · arrive 15 minutes early')]
  for i,(label,value) in enumerate(fields):field(217+i*58,label,value,local<4 and i==min(len(fields)-1,int(local/4*len(fields))))
  if local<4:hand(459,242+min(len(fields)-1,int(local/4*len(fields)))*58)
  else:hand(496,185)
 elif scene==10:
  center(230,'Hold an extra city, then drag',19,True)
  progress=max(0,min(1,(local-1)/2.5))
  for i,city in enumerate(['London','Melbourne','Paris']):
   y=277+i*82+(82*progress if i==0 else -82*progress if i==1 else 0);box(65,y,470,65,'#EAF1FC' if i==0 else LIGHT);text(85,y+22,'≡   '+city,22,True)
  text(80,558,'Bottom tabs work the same way',18,True)
  for i,tab in enumerate(['Home','Convert','World','My Trip','Translate']):
   shift=max(0,min(1,(local-3.5)/1.5))*96
   tx=65+i*96+(shift if i==2 else -shift if i==3 else 0)
   box(tx,608,87,63,'#EAF1FC' if i==2 else LIGHT);text(tx+7,630,tab,12,True)
  if local<3.5:hand(295,307+82*progress)
  elif local<5.5:hand(297+shift,635)
  else:hand(495,185)
 elif scene==11:
  field(223,'Selected city','Tokyo, Japan');field(292,'Observed conditions','Sunny · 25°C / 77°F');field(361,'Weather observed','Oct 5, 2026 · 3:00 PM PDT');field(430,'Forecast retrieved','Oct 5, 2026 · 3:05 PM PDT');field(499,'Forecast row time zone','Asia/Tokyo · Tokyo local time');field(568,'Hourly forecast','Tue 8 AM · 25°C / 77°F · Rain 10%')
  button(641,'Refresh');text(80,713,'Example forecast · predictions can change',15,c=GREY);hand(299,666)
 elif scene==12:
  for i,(label,value) in enumerate([('Box theme','Standard ✓'),('Home location','Manual · Los Angeles'),('24-hour time','Off'),('Analog clocks','On'),('Date and weekday','On'),('Time difference','On'),('Lock app','On · Face ID / device passcode'),('About & support','Help · offline video and written guide')]):field(220+i*63,label,value)
  hand(494,185)
 else:
  for i,(label,value) in enumerate([('Currency','Bundled or saved reference rates'),('Rate date','Oct 5, 2026 · example snapshot'),('Weather','Saved forecast · check retrieval time'),('Translation languages','Downloaded · ready offline'),('Saved entries','Coffee · suitcase · travel details'),('Help video','Included in the app · no connection')]):field(234+i*75,label,value)
  center(715,'Fresh updates require internet.',19,True,BLUE)
 action=['Edit either amount','Tap Use total','Tap Capture' if local<3.3 else 'Check price → Save','Add note → Tap Save','Choose units → Save','Drag → Return to now','Translate → Review → Save','Fill fields → Tap Save','Set local times → Save','Fill journey → Tap Save','Hold → Drag → Done','Refresh → Check dates','Choose options → Done','Prepare while connected'][scene]
 center(119,action,14,True,BLUE)
 box(24,832,552,146,'#EAF1FC')
 center(855,scenes[scene][1],20,True);center(900,scenes[scene][2],19)
 center(996,'Illustrated worked example · captions only',15,c=GREY)
 for i in range(14):d.rounded_rectangle((28+i*39,1034,61+i*39,1040),radius=3,fill=BLUE if i<=scene else '#D8E1EF')
 if frame%144==84:samples.append(im.copy())
 p.stdin.write(im.tobytes())
p.stdin.close();assert p.wait()==0
sheet=Image.new('RGB',(1200,2136),'white')
for i,im in enumerate(samples):sheet.paste(im.resize((300,534)),((i%4)*300,(i//4)*534))
sheet.save(ROOT/'tour_contact_sheet.jpg')
print('Rendered',DURATION,'seconds;', (OUTPUT/'Trip_Info_Quick_Tour.mp4').stat().st_size,'bytes')
