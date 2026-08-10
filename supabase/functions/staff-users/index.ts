import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.57.4";

const cors={"Access-Control-Allow-Origin":"https://tacos-don-luis.vercel.app","Access-Control-Allow-Headers":"authorization, apikey, content-type","Access-Control-Allow-Methods":"GET, POST, PATCH, OPTIONS","Content-Type":"application/json"};
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:cors});
const roles=["owner","admin","cashier","kitchen","waiter","driver"];

Deno.serve(async(req:Request)=>{
 if(req.method==="OPTIONS")return new Response("ok",{headers:cors});
 try{
  const url=new URL(req.url),token=(req.headers.get("Authorization")||"").replace(/^Bearer\s+/i,"");
  if(!token)return json({error:"Sesión requerida"},401);
  const admin=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,{auth:{persistSession:false,autoRefreshToken:false}});
  const {data:authData,error:authError}=await admin.auth.getUser(token);if(authError||!authData.user)return json({error:"Sesión inválida"},401);
  const body=req.method==="GET"?{}:await req.json().catch(()=>({}));
  const branchId=url.searchParams.get("branch_id")||String(body.branch_id||"");if(!branchId)return json({error:"Sucursal requerida"},400);
  const {data:actorMembership}=await admin.from("branch_memberships").select("role").eq("branch_id",branchId).eq("user_id",authData.user.id).eq("is_active",true).maybeSingle();
  if(!actorMembership||!["owner","admin"].includes(actorMembership.role))return json({error:"No tienes permiso para administrar usuarios"},403);
  if(req.method==="GET"){
   const {data:memberships,error}=await admin.from("branch_memberships").select("id,user_id,role,is_active,created_at").eq("branch_id",branchId).order("created_at");if(error)throw error;
   const ids=(memberships||[]).map(m=>m.user_id);const {data:profiles}=ids.length?await admin.from("profiles").select("id,full_name,phone").in("id",ids):{data:[]};
   const {data:usersData,error:usersError}=await admin.auth.admin.listUsers({page:1,perPage:1000});if(usersError)throw usersError;
   const pById=Object.fromEntries((profiles||[]).map(p=>[p.id,p])),eById=Object.fromEntries(usersData.users.map(u=>[u.id,u.email]));
   return json({users:(memberships||[]).map(m=>({...m,email:eById[m.user_id]||null,profiles:pById[m.user_id]||null}))});
  }
  if(req.method==="POST"&&body.action==="invite"){
   const email=String(body.email||"").trim().toLowerCase(),role=String(body.role||"");if(!email||!roles.includes(role))return json({error:"Correo o rol inválido"},400);
   const {data,error}=await admin.auth.admin.inviteUserByEmail(email,{redirectTo:"https://tacos-don-luis.vercel.app/admin/",data:{full_name:String(body.full_name||"").trim()}});if(error||!data.user)return json({error:error?.message||"No se pudo invitar"},400);
   await admin.from("profiles").upsert({id:data.user.id,full_name:String(body.full_name||"").trim()||null,phone:String(body.phone||"").trim()||null,account_type:"staff"});
   const {error:memberError}=await admin.from("branch_memberships").insert({branch_id:branchId,user_id:data.user.id,role,is_active:true});if(memberError)throw memberError;
   return json({ok:true,user_id:data.user.id});
  }
  if(req.method==="POST"&&body.action==="add_existing"){
   const email=String(body.email||"").trim().toLowerCase(),role=String(body.role||"");if(!email||!roles.includes(role))return json({error:"Correo o rol inválido"},400);
   const {data:usersData,error:usersError}=await admin.auth.admin.listUsers({page:1,perPage:1000});if(usersError)throw usersError;
   const user=usersData.users.find(u=>String(u.email||"").toLowerCase()===email);if(!user)return json({error:"No existe una cuenta con ese correo"},404);
   const {data:existing}=await admin.from("branch_memberships").select("id").eq("branch_id",branchId).eq("user_id",user.id).maybeSingle();
   const result=existing
    ?await admin.from("branch_memberships").update({role,is_active:true}).eq("id",existing.id).select("id,user_id,role,is_active").single()
    :await admin.from("branch_memberships").insert({branch_id:branchId,user_id:user.id,role,is_active:true}).select("id,user_id,role,is_active").single();
   if(result.error)throw result.error;
   await admin.from("profiles").update({account_type:"staff"}).eq("id",user.id);
   return json({ok:true,user_id:user.id,membership:result.data});
  }
  if(req.method==="PATCH"&&body.membership_id){
   const patch:Record<string,unknown>={};if(body.role&&roles.includes(body.role))patch.role=body.role;if(typeof body.is_active==="boolean")patch.is_active=body.is_active;
   if(!Object.keys(patch).length)return json({error:"Sin cambios válidos"},400);
   const {data,error}=await admin.from("branch_memberships").update(patch).eq("id",body.membership_id).eq("branch_id",branchId).select("id,user_id,role,is_active").single();if(error)throw error;return json({ok:true,membership:data});
  }
  return json({error:"Acción no soportada"},400);
 }catch(error){console.error(error);return json({error:error instanceof Error?error.message:"Error interno"},500)}
});
