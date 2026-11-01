import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { z } from 'zod';
import { createPublicClient, supabaseAdmin } from './lib/supabase.js';

export const authRouter=Router();
const loginLimiter=rateLimit({windowMs:60_000,limit:5,standardHeaders:'draft-8',legacyHeaders:false,message:{error:{code:'RATE_LIMITED',message:'Too many attempts. Wait a minute and try again.'}}});
const resetLimiter=rateLimit({windowMs:60*60_000,limit:15,standardHeaders:'draft-8',legacyHeaders:false});
const resetByEmail=new Map<string,number[]>();
authRouter.post('/login',loginLimiter,async(req,res)=>{
  const parsed=z.object({email:z.email(),password:z.string().min(1)}).safeParse(req.body);
  if(!parsed.success)return res.status(400).json({error:{code:'VALIDATION_ERROR',message:'Enter a valid email and password.'}});
  const publicClient=createPublicClient();
  const {data,error}=await publicClient.auth.signInWithPassword(parsed.data);
  if(error||!data.user||!data.session)return res.status(401).json({error:{code:'INVALID_CREDENTIALS',message:'Email or password is incorrect. Please try again.'}});
  const {data:profile}=await supabaseAdmin.from('profiles').select('*').eq('id',data.user.id).maybeSingle();
  if(!profile||!profile.is_active){await publicClient.auth.signOut();return res.status(401).json({error:{code:'INVALID_CREDENTIALS',message:'Email or password is incorrect. Please try again.'}});}
  return res.json({data:{session:{access_token:data.session.access_token,refresh_token:data.session.refresh_token},profile}});
});
authRouter.post('/forgot-password',resetLimiter,async(req,res)=>{
  const emailParsed=z.email().safeParse(req.body?.email);
  if(emailParsed.success){
    const email=emailParsed.data.toLowerCase();const now=Date.now();const times=(resetByEmail.get(email)||[]).filter(t=>now-t<60*60_000);
    if(times.length<3){times.push(now);resetByEmail.set(email,times);const publicClient=createPublicClient();const redirectOrigin=(process.env.CORS_ORIGIN||'http://localhost:5173').split(',')[0]?.trim()||'http://localhost:5173';await publicClient.auth.resetPasswordForEmail(email,{redirectTo:`${redirectOrigin}/reset-password`});}
  }
  // Do not reveal whether an account exists.
  return res.json({data:{accepted:true}});
});
