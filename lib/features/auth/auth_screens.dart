import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/common.dart';
import '../../shared/models/models.dart';
import '../../shared/providers.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});
  @override Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: DecoratedBox(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF5B3CF5), Color(0xFF8D3CF5), Color(0xFFFF6B4A)])),
      child: const SizedBox.expand(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.confirmation_number_rounded, color: Colors.white, size: 84), SizedBox(height: 18), Text('TicketHub', style: TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800)), SizedBox(height: 8), Text('Tickets. Experiences. One place.', style: TextStyle(color: Colors.white70)), SizedBox(height: 30), CircularProgressIndicator(color: Colors.white)])),
    ),
  );
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override State<OnboardingScreen> createState() => _OnboardingScreenState();
}
class _OnboardingScreenState extends State<OnboardingScreen> {
  final controller = PageController(); int page = 0;
  final data = const [
    (Icons.explore_rounded, 'Discover more', 'Find cinemas, concerts, sports, workshops, attractions and experiences in one marketplace.'),
    (Icons.event_seat_rounded, 'Choose your way', 'Select ticket quantities or pick exact seats where a venue supports seating.'),
    (Icons.qr_code_2_rounded, 'Your ticket, ready', 'Keep digital QR tickets, booking history and notifications together.'),
  ];
  @override Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Column(children: [
    Expanded(child: PageView.builder(controller: controller, itemCount: data.length, onPageChanged: (v) => setState(() => page=v), itemBuilder: (_, i) { final x=data[i]; return Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(x.$1, size: 120, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 34), Text(x.$2, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center), const SizedBox(height: 14), Text(x.$3, textAlign: TextAlign.center)])); })),
    Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(data.length, (i) => AnimatedContainer(duration: const Duration(milliseconds: 220), margin: const EdgeInsets.all(4), width: i==page?24:8, height:8, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: i==page?Theme.of(context).colorScheme.primary:Colors.grey.shade400)))),
    Padding(padding: const EdgeInsets.all(24), child: page < data.length-1 ? GradientButton(label: 'Continue', onPressed: () => controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut)) : Column(children: [GradientButton(label: 'Continue as Customer', onPressed: () => context.go('/register?role=customer')), const SizedBox(height: 12), OutlinedButton(onPressed: () => context.go('/register?role=owner'), child: const SizedBox(height: 48, child: Center(child: Text('Continue as Business Owner')))), TextButton(onPressed: () => context.go('/login'), child: const Text('Already registered? Sign in'))])),
  ])));
}

class LoginScreen extends ConsumerStatefulWidget { const LoginScreen({super.key}); @override ConsumerState<LoginScreen> createState()=>_LoginScreenState(); }
class _LoginScreenState extends ConsumerState<LoginScreen> {
  final formKey=GlobalKey<FormState>(); final email=TextEditingController(); final password=TextEditingController(); bool busy=false; bool hide=true;
  @override void dispose(){email.dispose();password.dispose();super.dispose();}
  Future<void> submit() async { if(!formKey.currentState!.validate()) return; setState(()=>busy=true); try { await ref.read(repositoryProvider).signIn(email.text,password.text); ref.invalidate(currentProfileProvider); if(mounted) context.go('/'); } catch(e){ if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); } finally { if(mounted)setState(()=>busy=false); } }
  @override Widget build(BuildContext context)=>Scaffold(body:SafeArea(child:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:460),child:Form(key:formKey,child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Icon(Icons.confirmation_number_rounded,size:68,color:Theme.of(context).colorScheme.primary),const SizedBox(height:20),Text('Welcome back',style:Theme.of(context).textTheme.headlineSmall,textAlign:TextAlign.center),const SizedBox(height:28),
    TextFormField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Email',prefixIcon:Icon(Icons.email_outlined)),validator:(v)=>v==null||!v.contains('@')?'Enter a valid email':null),const SizedBox(height:14),
    TextFormField(controller:password,obscureText:hide,decoration:InputDecoration(labelText:'Password',prefixIcon:const Icon(Icons.lock_outline),suffixIcon:IconButton(onPressed:()=>setState(()=>hide=!hide),icon:Icon(hide?Icons.visibility:Icons.visibility_off))),validator:(v)=>v==null||v.length<8?'Password must be at least 8 characters':null),const SizedBox(height:20),
    GradientButton(label:'Sign In',busy:busy,onPressed:submit,icon:Icons.login),const SizedBox(height:10),TextButton(onPressed:()=>context.go('/onboarding'),child:const Text('Create a new account')),
  ])))))));
}

class RegisterScreen extends ConsumerStatefulWidget { const RegisterScreen({super.key, required this.role}); final UserRole role; @override ConsumerState<RegisterScreen> createState()=>_RegisterScreenState(); }
class _RegisterScreenState extends ConsumerState<RegisterScreen>{
  final formKey=GlobalKey<FormState>(); final name=TextEditingController();final email=TextEditingController();final phone=TextEditingController();final pass=TextEditingController();final confirm=TextEditingController();bool busy=false;bool accepted=false;
  @override void dispose(){name.dispose();email.dispose();phone.dispose();pass.dispose();confirm.dispose();super.dispose();}
  Future<void> submit()async{if(!formKey.currentState!.validate()||!accepted){if(!accepted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Please accept the terms to continue.')));return;}setState(()=>busy=true);try{await ref.read(repositoryProvider).signUp(fullName:name.text,email:email.text,phone:phone.text,password:pass.text,role:widget.role);if(mounted){showDialog<void>(context:context,builder:(c)=>AlertDialog(title:const Text('Account created'),content:const Text('If email confirmation is enabled in Supabase, confirm your email first. Then sign in to continue.'),actions:[TextButton(onPressed:(){Navigator.pop(c);context.go('/login');},child:const Text('Sign in'))]));}}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}finally{if(mounted)setState(()=>busy=false);}}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(widget.role==UserRole.owner?'Owner registration':'Customer registration')),body:SafeArea(child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:520),child:Form(key:formKey,child:Column(children:[
    TextFormField(controller:name,decoration:const InputDecoration(labelText:'Full name',prefixIcon:Icon(Icons.person_outline)),validator:(v)=>v==null||v.trim().length<2?'Enter your name':null),const SizedBox(height:12),TextFormField(controller:email,decoration:const InputDecoration(labelText:'Email',prefixIcon:Icon(Icons.email_outlined)),validator:(v)=>v==null||!v.contains('@')?'Enter a valid email':null),const SizedBox(height:12),TextFormField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Phone',prefixIcon:Icon(Icons.phone_outlined)),validator:(v)=>v==null||v.trim().length<7?'Enter a valid phone number':null),const SizedBox(height:12),TextFormField(controller:pass,obscureText:true,decoration:const InputDecoration(labelText:'Password',prefixIcon:Icon(Icons.lock_outline)),validator:(v)=>v==null||v.length<8?'Use at least 8 characters':null),const SizedBox(height:12),TextFormField(controller:confirm,obscureText:true,decoration:const InputDecoration(labelText:'Confirm password'),validator:(v)=>v!=pass.text?'Passwords do not match':null),CheckboxListTile(value:accepted,onChanged:(v)=>setState(()=>accepted=v??false),title:const Text('I agree to the platform terms and privacy policy'),controlAffinity:ListTileControlAffinity.leading,contentPadding:EdgeInsets.zero),const SizedBox(height:12),SizedBox(width:double.infinity,child:GradientButton(label:'Create account',busy:busy,onPressed:submit)),TextButton(onPressed:()=>context.go('/login'),child:const Text('Already registered? Sign in')),
  ])))))));
}

class ForbiddenScreen extends StatelessWidget { const ForbiddenScreen({super.key}); @override Widget build(BuildContext context)=>Scaffold(body:Center(child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.lock_outline,size:64),const SizedBox(height:12),const Text('You do not have access to this area.'),const SizedBox(height:16),FilledButton(onPressed:()=>context.go('/'),child:const Text('Go home'))]))); }
