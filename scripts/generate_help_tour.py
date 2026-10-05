from PIL import Image, ImageDraw, ImageFont
import subprocess, math
from pathlib import Path
ROOT=Path(__file__).resolve().parent
W,H=600,1068
BLUE='#287AF5'; INK='#172336'; GREY='#718094'; LIGHT='#F1F4F9'
def font(n,b=False): return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans'+('-Bold' if b else '')+'.ttf',n)
scenes=[('Start with your cities',['Choose Home and Destination.','Edit either amount to convert.']),('Read prices or units',['Choose Camera or Photo.','Review the values before saving.']),('Compare city times',['Drag from Now to compare.','Return to now restores live clocks.']),('Translate and keep details',['Choose languages, then translate.','Save notes and reference photos.']),('Make it yours',['Hold and drag tabs or extra cities.','Tap Done to keep the new order.']),('Ready for offline travel',['Refresh rates and weather first.','Download translation languages.'])]
p=subprocess.Popen(['ffmpeg','-y','-loglevel','error','-f','rawvideo','-pix_fmt','rgb24','-s',f'{W}x{H}','-r','24','-i','-','-an','-c:v','libx264','-preset','fast','-crf','25','-pix_fmt','yuv420p','-movflags','+faststart',str(ROOT/'Trip_Info_Quick_Tour.mp4')],stdin=subprocess.PIPE)
samples=[]
for frame in range(32*24):
 t=frame/24; scene=min(5,int(t/5.3334)); local=t-scene*5.3334
 im=Image.new('RGB',(W,H),'#F9FBFF'); d=ImageDraw.Draw(im)
 def text(x,y,s,n=22,b=False,c=INK): d.text((x,y),s,font=font(n,b),fill=c)
 def center(y,s,n=22,b=False,c=INK): d.text((W/2,y),s,font=font(n,b),fill=c,anchor='mt')
 def box(x,y,w,h,fill=LIGHT): d.rounded_rectangle((x,y,x+w,y+h),radius=18,fill=fill)
 def ripple(x,y):
  radius=14+18*(.5+.5*math.sin(local*3)); d.ellipse((x-radius,y-radius,x+radius,y+radius),outline=BLUE,width=3);d.ellipse((x-5,y-5,x+5,y+5),fill=BLUE)
 text(32,34,'TRIP INFO',17,True,BLUE);text(392,34,'QUICK TOUR',15,True,GREY)
 center(96,scenes[scene][0],27,True)
 box(36,166,528,636,'#DDE5F0');box(42,160,516,632,'white')
 title=['Home','Photo prices','World Time','Translate','Tab order','Before you leave'][scene]
 center(188,title,27,True);text(467,191,'Done',17,True,BLUE)
 if scene==0:
  box(65,252,225,172,'#EAF4ED');box(310,252,225,172,'#EAF1FC')
  for x,role,city,clock in [(85,'Home','Los Angeles','1:08 PM'),(330,'Destination','Tokyo','5:08 AM')]:
   text(x,272,role,17,c=GREY);text(x,309,city,21,True);text(x,356,clock,27,True)
  center(461,'Quick conversion',23,True)
  box(65,509,225,110);box(310,509,225,110)
  text(84,527,'USD',18,c=GREY);text(330,527,'JPY',18,c=GREY)
  text(84,562,'100.00',29,True);text(330,562,'≈ 15,792',29,True)
  center(645,'Example amounts · reference rates',16,c=GREY);ripple(191,581)
 elif scene==1:
  box(65,244,225,68,BLUE);box(310,244,225,68,'#EAF1FC')
  text(85,264,'✓ Camera',22,True,'white');text(362,264,'Photo',22,True,BLUE)
  box(65,334,470,218,'#DCE9DF');box(134,369,330,146,'#FFFFF4')
  center(391,'MENU',22,True);center(441,'Coffee   ¥ 500',29,True)
  box(65,577,470,72);text(87,599,'Review detected prices',22,True)
  box(65,672,470,62,BLUE);center(689,'Save with a note',22,True,'white');ripple(301,706)
 elif scene==2:
  box(65,255,225,150,'#EAF4ED');box(310,255,225,150,'#EAF1FC')
  offset=round(4*max(0,min(1,(local-1)/2))) if local<4 else 0
  text(84,278,'Los Angeles',21,True);text(331,278,'Tokyo',21,True)
  text(84,330,f'{1+offset}:08 PM',27,True);text(331,330,f'{5+offset}:08 AM',27,True)
  for i,(city,tm) in enumerate([('London',f'{(9+offset-1)%12+1}:08 '+('PM' if offset<3 else 'AM')),('Melbourne',f'{7+offset}:08 AM')]):
   box(65,430+i*87,470,70);text(84,450+i*87,city,21,True);text(390,452+i*87,tm,18)
  text(75,632,'Compare city times',20,True);text(367,635,'Return to now',17,c=BLUE)
  d.line((85,696,515,696),fill='#D3DCE8',width=8);x=300+offset*8;d.line((85,696,x,696),fill=BLUE,width=8);d.ellipse((x-14,682,x+14,710),fill=BLUE)
  center(726,'Now · 0 hours' if offset==0 else f'+{offset} hours from now',19,c=GREY);ripple(x,696)
 elif scene==3:
  box(65,252,470,94);text(85,271,'Japanese  →  English (General)',21,True);text(85,309,'Choose your language pair',16,c=GREY)
  box(65,372,470,85);text(85,394,'Enter text or choose a photo',21)
  box(65,482,470,64,BLUE);center(500,'Translate',22,True,'white')
  box(65,574,470,141);text(85,594,'Translation',20,True);text(85,635,'Hello. Thank you!',25);text(85,677,'Add a note and Save',17,c=GREY);ripple(305,514)
 elif scene==4:
  center(261,'Touch and hold to reorder',22,True)
  cities=['London','Melbourne','Paris'];progress=max(0,min(1,(local-1.5)/2))
  for i,city in enumerate(cities):
   y=324+i*105
   if i==0:y+=105*progress
   if i==1:y-=105*progress
   box(65,y,470,85,'#EAF1FC' if i==0 else LIGHT);text(86,y+26,'≡   '+city,24,True)
  center(662,'Hold a bottom tab to do the same.',18,c=GREY);ripple(294,369+105*progress)
 else:
  for i,(main,sub) in enumerate([('Rates','Saved rates include their date.'),('Weather','Saved forecasts show update time.'),('Translation','Download languages while online.'),('Help & saved entries','Available on this device offline.')]):
   y=252+i*115;box(65,y,470,96);text(85,y+15,'✓ '+main,23,True);text(85,y+56,sub,17,c=GREY)
  center(738,'Fresh updates need internet.',19,True,BLUE)
 box(30,829,540,145,'#EAF1FC')
 for j,line in enumerate(scenes[scene][1]):center(859+j*39,line,23,j==0)
 center(994,'Illustrated guide · captioned · no sound needed',15,c=GREY)
 for i in range(6):d.rounded_rectangle((42+i*87,1034,115+i*87,1040),radius=3,fill=BLUE if i<=scene else '#D8E1EF')
 if frame in [60,180,300,420,540,660]:samples.append(im.copy())
 p.stdin.write(im.tobytes())
p.stdin.close();assert p.wait()==0
sheet=Image.new('RGB',(900,1068),'white')
for i,im in enumerate(samples):sheet.paste(im.resize((300,534)),((i%3)*300,(i//3)*534))
sheet.save(ROOT/'tour_contact_sheet.jpg')
print('Tour rendered:',(ROOT/'Trip_Info_Quick_Tour.mp4').stat().st_size,'bytes')
