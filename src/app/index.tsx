import {useEffect,useState} from 'react';
import {View,Text,TextInput,Pressable,ScrollView,ActivityIndicator,StyleSheet} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import {me,login,logout,list,type Resource} from '../lib/api';
type Page='inicio'|Resource|'conta';
const sections:[Page,string][]=[['inicio','Início'],['plots','Talhões'],['devices','Drones'],['operations','Operações'],['conta','Conta']];
function extract(r:any):any[]{const x=r?.data??r;const y=x?.data??x;return [y?.records,y?.list,y?.rows,y?.items,x?.records,x?.list,y,x].find(Array.isArray)??[]}
function accountDisplayName(session:any):string {
 const profile=session?.user?.data??{};
 const context=session?.context??{};
 const candidates=[
  profile.accountName,profile.account?.accountName,profile.account?.name,
  profile.nickName,profile.nickname,profile.realName,profile.fullName,profile.name,
  context.accountName,context.nickName,context.nickname,context.realName,context.name,
  session?.username,
 ];
 const value=candidates.find((candidate:unknown)=>typeof candidate==='string'&&candidate.trim().length>0&&!candidate.includes('@'));
 return typeof value==='string'?value.trim():'Usuário';
}
export default function Home(){
 const [user,setUser]=useState<string|null>(null),[accountName,setAccountName]=useState('Usuário'),[name,setName]=useState(''),[password,setPassword]=useState(''),[page,setPage]=useState<Page>('inicio'),[rows,setRows]=useState<any[]>([]),[busy,setBusy]=useState(false),[boot,setBoot]=useState(true),[error,setError]=useState('');
 useEffect(()=>{me().then(r=>{if(r.ok){setUser(r.username??'Usuário');setAccountName(accountDisplayName(r))}}).catch(()=>{}).finally(()=>setBoot(false))},[]);
 async function enter(){setBusy(true);setError('');try{await login(name.trim(),password);const r=await me();if(!r.ok)throw Error('Sessão não validada');setUser(r.username??name);setAccountName(accountDisplayName(r));setPassword('')}catch(e){setError(String(e instanceof Error?e.message:e))}finally{setBusy(false)}}
 async function open(p:Page){setPage(p);setRows([]);setError('');if(p==='inicio'||p==='conta')return;setBusy(true);try{setRows(extract(await list(p)))}catch(e){setError(String(e instanceof Error?e.message:e))}finally{setBusy(false)}}
 async function leave(){setBusy(true);try{await logout()}catch{}setUser(null);setAccountName('Usuário');setPage('inicio');setRows([]);setBusy(false)}
 const button=(label:string,fn:()=>void)=><Pressable style={s.button} onPress={fn} disabled={busy}><Text style={s.buttonText}>{label}</Text></Pressable>;
 return <SafeAreaView style={s.root}><View style={s.header}><View style={s.brandMark}/><View><Text style={s.brand}>ATLANTIC <Text style={s.green}>SMARTFARM</Text></Text><Text style={s.brandSubtitle}>GESTÃO AGRÍCOLA</Text></View></View>
 {boot?<ActivityIndicator color="#67C23A" style={{marginTop:90}}/>:!user?<ScrollView contentContainerStyle={s.body}>
 <Text style={s.kicker}>SMARTFARM MOBILE</Text><Text style={s.title}>Gestão agrícola em suas mãos.</Text><Text style={s.sub}>Acesse com sua conta EAVision.</Text>
 <View style={s.card}><Text style={s.label}>Usuário</Text><TextInput value={name} onChangeText={setName} autoCapitalize="none" style={s.input} placeholderTextColor="#8BA1AA" placeholder="Login"/><Text style={s.label}>Senha</Text><TextInput secureTextEntry value={password} onChangeText={setPassword} style={s.input} placeholder="Senha" placeholderTextColor="#8BA1AA"/>{button(busy?'Entrando...':'Entrar no SmartFarm',enter)}</View>{!!error&&<Text style={s.error}>{error}</Text>}
 </ScrollView>:<><ScrollView contentContainerStyle={s.body}><Text style={s.kicker}>SMARTFARM ATLANTIC</Text><Text style={s.title}>{page==='inicio'?'Olá, '+accountName:sections.find(x=>x[0]===page)?.[1]}</Text>
 {page==='inicio'&&<><Text style={s.sub}>Gerencie os dados de sua operação agrícola.</Text><Text style={s.sectionLabel}>GERENCIAMENTO</Text>{sections.filter(x=>x[0]!=='inicio'&&x[0]!=='conta').map(x=><Pressable key={x[0]} style={s.card} onPress={()=>open(x[0])}><Text style={s.cardTitle}>{x[1]} ›</Text><Text style={s.sub}>Consultar dados da EAVision</Text></Pressable>)}</>}
 {page==='conta'&&<View style={s.card}><Text style={s.cardTitle}>Sessão conectada</Text><Text style={s.sub}>{user}</Text>{button('Sair da conta',leave)}</View>}
 {page!=='inicio'&&page!=='conta'&&<>{button('Atualizar',()=>open(page))}{busy&&<ActivityIndicator color="#67C23A"/>}{!!error&&<Text style={s.error}>{error}</Text>}{!busy&&!error&&rows.length===0&&<Text style={s.sub}>Nenhum registro retornado para esta conta.</Text>}{rows.map((r,i)=><View key={String(r.id??i)} style={s.card}><Text style={s.cardTitle}>{r.name??r.fieldName??r.uavName??r.taskName??'Registro '+(i+1)}</Text><Text style={s.sub}>{r.id!==undefined?'ID: '+r.id:'Dados recebidos do SmartFarm'}</Text></View>)}</>}
 </ScrollView><View style={s.nav}>{sections.map(x=><Pressable key={x[0]} onPress={()=>open(x[0])}><Text style={[s.tab,page===x[0]&&s.green]}>{x[1]}</Text></Pressable>)}</View></>}
 </SafeAreaView>
}
// Identidade visual Atlantic SmartFarm — alinhada ao atlantic-theme.css oficial.
const palette = {
 background:'#071019', header:'#081422', surface:'#0B1725', panel:'#0E1A2A',
 border:'rgba(145,175,220,0.18)', blue:'#1E78FF', blueLight:'#5EA1FF',
 gold:'#C18A53', text:'#F4F7FB', muted:'#9EAFC3', danger:'#FF6F78',
};
const s=StyleSheet.create({
 root:{flex:1,backgroundColor:palette.background},
 header:{minHeight:68,paddingHorizontal:21,paddingVertical:14,flexDirection:'row',alignItems:'center',gap:12,backgroundColor:palette.header,borderBottomColor:palette.border,borderBottomWidth:1},
 brandMark:{width:4,height:34,borderRadius:3,backgroundColor:palette.gold},
 brand:{color:palette.text,fontWeight:'800',fontSize:18,letterSpacing:0.5},
 brandSubtitle:{color:palette.muted,fontSize:9,letterSpacing:2.1,fontWeight:'700',marginTop:2},
 green:{color:palette.blueLight},
 body:{paddingHorizontal:20,paddingTop:24,gap:16,paddingBottom:40},
 kicker:{color:palette.gold,fontSize:11,fontWeight:'800',letterSpacing:1.6},
 title:{color:palette.text,fontSize:28,fontWeight:'800',letterSpacing:-0.6,lineHeight:35},
 sectionLabel:{marginTop:7,color:palette.muted,fontSize:11,fontWeight:'700',letterSpacing:1.8},
 sub:{color:palette.muted,fontSize:14,lineHeight:21},
 card:{backgroundColor:palette.panel,borderWidth:1,borderColor:palette.border,borderRadius:14,padding:19,gap:12},
 cardTitle:{fontSize:17,fontWeight:'700',color:palette.text},
 label:{color:palette.text,fontSize:13,fontWeight:'600'},
 input:{color:palette.text,backgroundColor:'rgba(54,78,105,0.36)',borderColor:'rgba(130,170,220,0.28)',borderWidth:1,borderRadius:10,paddingHorizontal:14,height:49},
 button:{minHeight:46,backgroundColor:palette.surface,borderWidth:1,borderColor:'rgba(30,120,255,0.5)',paddingHorizontal:16,paddingVertical:12,borderRadius:10,alignItems:'center',justifyContent:'center'},
 buttonText:{color:palette.text,fontWeight:'700',fontSize:14},
 error:{color:palette.danger,fontSize:13},
 nav:{flexDirection:'row',justifyContent:'space-around',alignItems:'center',minHeight:64,paddingHorizontal:9,paddingVertical:12,borderTopColor:palette.border,borderTopWidth:1,backgroundColor:palette.header},
 tab:{color:'#B4C2D0',fontSize:11,fontWeight:'700'},
});
