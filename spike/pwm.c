#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <wayland-client.h>
#include "pwm-client.h"
static struct org_kde_plasma_window_management *pwm;
static void t(void*d,struct org_kde_plasma_window*w,const char*s){printf("PWMWIN title=%s\n",s);}
static void a(void*d,struct org_kde_plasma_window*w,const char*s){printf("PWMWIN appid=%s\n",s);}
static void nop(){}
static void *wl[64];
static void win(void*d,struct org_kde_plasma_window_management*m,uint32_t id,const char*uuid){
 struct org_kde_plasma_window*w=org_kde_plasma_window_management_get_window_by_uuid(m,uuid);
 if(w){for(int i=0;i<64;i++)if(!wl[i])wl[i]=(void*)nop;wl[0]=(void*)t;wl[1]=(void*)a;org_kde_plasma_window_add_listener(w,(void*)wl,0);};printf("PWMWIN window uuid=%s\n",uuid);}
static struct org_kde_plasma_window_management_listener ml={.window_with_uuid=win,.show_desktop_changed=nop,.window=nop,.stacking_order_changed=nop,.stacking_order_uuid_changed=nop,.stacking_order_changed_2=nop};
static void reg(void*d,struct wl_registry*r,uint32_t n,const char*i,uint32_t v){
 if(!strcmp(i,"org_kde_plasma_window_management")){pwm=wl_registry_bind(r,n,&org_kde_plasma_window_management_interface,v<17?v:17);org_kde_plasma_window_management_add_listener(pwm,&ml,0);}}
static struct wl_registry_listener rl={reg,nop};
int main(){struct wl_display*d=wl_display_connect(0);if(!d){puts("PWM connect fail");return 1;}
 struct wl_registry*r=wl_display_get_registry(d);wl_registry_add_listener(r,&rl,0);
 wl_display_roundtrip(d);wl_display_roundtrip(d);wl_display_roundtrip(d);printf("PWM bound=%d\n",pwm!=0);return 0;}
