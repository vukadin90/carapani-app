import webpush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2";
const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type","Access-Control-Allow-Methods":"POST, OPTIONS"};
const response=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,"Content-Type":"application/json"}});
Deno.serve(async(req)=>{
 if(req.method==="OPTIONS")return new Response("ok",{headers:cors});
 if(req.method!=="POST")return response({error:"Method not allowed"},405);
 try{
  const url=Deno.env.get("SUPABASE_URL"),anon=Deno.env.get("SUPABASE_ANON_KEY"),serviceKey=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")||Deno.env.get("MY_SERVICE_ROLE_KEY"),publicKey=Deno.env.get("VAPID_PUBLIC_KEY"),privateKey=Deno.env.get("VAPID_PRIVATE_KEY");
  const missing=[["SUPABASE_URL",url],["SUPABASE_ANON_KEY",anon],["SUPABASE_SERVICE_ROLE_KEY / MY_SERVICE_ROLE_KEY",serviceKey],["VAPID_PUBLIC_KEY",publicKey],["VAPID_PRIVATE_KEY",privateKey]].filter((x)=>!x[1]).map((x)=>x[0]);
  if(missing.length){console.error("Missing push secrets:",missing);return response({error:"Nedostaju podešavanja za push: "+missing.join(", ")},500);}
  const token=(req.headers.get("Authorization")||"").replace(/^Bearer\s+/i,"");if(!token)return response({error:"Unauthorized"},401);
  const userClient=createClient(url,anon,{global:{headers:{Authorization:`Bearer ${token}`}}});
  const {data:{user},error:userError}=await userClient.auth.getUser(token);if(userError||!user)return response({error:"Unauthorized"},401);
  const admin=createClient(url,serviceKey);
  const {data:sender,error:senderError}=await admin.from("profiles").select("id,approved,is_admin").eq("id",user.id).maybeSingle();
  if(senderError){console.error("Push sender profile lookup failed:",senderError.message);return response({error:"Greška pri proveri članstva: "+senderError.message},500);}
  console.log("Push sender check:",{userId:user.id,profileFound:!!sender,approved:sender?.approved===true});
  if(!sender)return response({error:"Profil člana nije pronađen u tabeli profiles."},403);
  if(sender.approved!==true)return response({error:"Član nije odobren za prijem/slanje klupskih obaveštenja.",approved:sender.approved??null},403);
  const payload=await req.json();if(!["ride","event","announcement"].includes(payload.kind)||typeof payload.title!=="string"||typeof payload.body!=="string")return response({error:"Invalid notification"},400);
  webpush.setVapidDetails("mailto:carapani-klub@example.com",publicKey,privateKey);
  const {data:members,error:membersError}=await admin.from("profiles").select("id").eq("approved",true);if(membersError)throw membersError;
  const ids=(members||[]).map((m:any)=>m.id);if(!ids.length)return response({sent:0,failed:0});
  const {data:subs,error:subsError}=await admin.from("push_subscriptions").select("id,user_id,endpoint,p256dh,auth").in("user_id",ids);if(subsError)throw subsError;
  let sent=0,failed=0;const notification=JSON.stringify({title:payload.title.slice(0,100),body:payload.body.slice(0,180),tag:`carapani-${payload.kind}-${crypto.randomUUID()}`,url:"./"});
  for(const row of subs||[]){try{await webpush.sendNotification({endpoint:row.endpoint,keys:{p256dh:row.p256dh,auth:row.auth}},notification);sent++;}catch(err){failed++;const status=(err as any)?.statusCode;if(status===404||status===410)await admin.from("push_subscriptions").delete().eq("id",row.id);}}
  return response({sent,failed});
 }catch(error){console.error(error);return response({error:(error as Error).message||"Internal error"},500);}
});
