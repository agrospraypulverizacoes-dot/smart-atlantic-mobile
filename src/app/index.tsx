import {useEffect,useState} from 'react';
import {View,Text,TextInput,Pressable,ScrollView,ActivityIndicator,StyleSheet} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import {me,login,logout,list,type Resource} from '../lib/api';
type Page='inicio'|Resource|'conta';
const sections:[Page,string][]=[['inicio','Início'],['plots','Talhões'],['devices','Drones'],['operations','Operações'],['conta','Conta']];
function extract(r:any):any[]{const x=r?.data??r;const y=x?.data??x;return [y?.records,y?.list,y?.rows,y?.items,x?.records,x?.list,y,x].find(Array.isArray)??[]}
export default function Home(){
 const [user,setUser]=useState<string|null>(null),[name,setName]=useState(''),[password,setPassword]=useState(''),[page,setPage]=useState<Page>('inicio'),[rows,setRows]=useState<any[]>([]),[busy,setBusy]=useState(false),[boot,setBoot]=useState(true),[error,setError]=useState('');
 useEffect(()=>{me().then(r=>{if(r.ok)setUser(r.username??'Usuário')}).catch(()=>{}).finally(()=>setBoot(false))},[]);
 async function enter(){setBusy(true);setError('');try{await login(name.trim(),password);const r=await me();if(!r.ok)throw Error('Sessão não validada');setUser(r.username??name);setPassword('')}catch(e){setError(String(e instanceof Error?e.message:e))}finally{setBusy(false)}}
 async function open(p:Page){setPage(p);setRows([]);setError('');if(p==='inicio'||p==='conta')return;setBusy(true);try{setRows(extract(await list(p)))}catch(e){setError(String(e instanceof Error?e.message:e))}finally{setBusy(false)}}
 async function leave(){setBusy(true);try{await logout()}catch{}setUser(null);setPage('inicio');setRows([]);setBusy(false)}
 const button=(label:string,fn:()=>void)=><Pressable style={s.button} onPress={fn} disabled={busy}><Text style={s.buttonText}>{label}</Text></Pressable>;
 return <SafeAreaView style={s.root}><View style={s.header}><Text style={s.brand}>ATLANTIC <Text style={s.green}>SMARTFARM</Text></Text></View>
 {boot?<ActivityIndicator color="#67C23A" style={{marginTop:90}}/>:!user?<ScrollView contentContainerStyle={s.body}>
 <Text style={s.kicker}>SMARTFARM MOBILE</Text><Text style={s.title}>Gestão agrícola em suas mãos.</Text><Text style={s.sub}>Acesse com sua conta EAVision.</Text>
 <View style={s.card}><Text style={s.label}>Usuário</Text><TextInput value={name} onChangeText={setName} autoCapitalize="none" style={s.input} placeholderTextColor="#8BA1AA" placeholder="Login"/><Text style={s.label}>Senha</Text><TextInput secureTextEntry value={password} onChangeText={setPassword} style={s.input} placeholder="Senha" placeholderTextColor="#8BA1AA"/>{button(busy?'Entrando...':'Entrar no SmartFarm',enter)}</View>{!!error&&<Text style={s.error}>{error}</Text>}
 </ScrollView>:<><ScrollView contentContainerStyle={s.body}><Text style={s.kicker}>SMARTFARM ATLANTIC</Text><Text style={s.title}>{page==='inicio'?'Olá, '+user:sections.find(x=>x[0]===page)?.[1]}</Text>
 {page==='inicio'&&<><Text style={s.sub}>Gerencie os dados de sua operação agrícola.</Text>{sections.filter(x=>x[0]!=='inicio'&&x[0]!=='conta').map(x=><Pressable key={x[0]} style={s.card} onPress={()=>open(x[0])}><Text style={s.cardTitle}>{x[1]} ›</Text><Text style={s.sub}>Consultar dados da EAVision</Text></Pressable>)}</>}
 {page==='conta'&&<View style={s.card}><Text style={s.cardTitle}>Sessão conectada</Text><Text style={s.sub}>{user}</Text>{button('Sair da conta',leave)}</View>}
 {page!=='inicio'&&page!=='conta'&&<>{button('Atualizar',()=>open(page))}{busy&&<ActivityIndicator color="#67C23A"/>}{!!error&&<Text style={s.error}>{error}</Text>}{!busy&&!error&&rows.length===0&&<Text style={s.sub}>Nenhum registro retornado para esta conta.</Text>}{rows.map((r,i)=><View key={String(r.id??i)} style={s.card}><Text style={s.cardTitle}>{r.name??r.fieldName??r.uavName??r.taskName??'Registro '+(i+1)}</Text><Text style={s.sub}>{r.id!==undefined?'ID: '+r.id:'Dados recebidos do SmartFarm'}</Text></View>)}</>}
 </ScrollView><View style={s.nav}>{sections.map(x=><Pressable key={x[0]} onPress={()=>open(x[0])}><Text style={[s.tab,page===x[0]&&s.green]}>{x[1]}</Text></Pressable>)}</View></>}
 </SafeAreaView>
}
const s=StyleSheet.create({root:{flex:1,backgroundColor:'#07131C'},header:{padding:20,borderBottomColor:'#24424A',borderBottomWidth:1},brand:{color:'#F5FAF7',fontWeight:'900',letterSpacing:1},green:{color:'#67C23A'},body:{padding:22,gap:16,paddingBottom:40},kicker:{color:'#67C23A',fontSize:12,fontWeight:'800',letterSpacing:2},title:{color:'#F5FAF7',fontSize:29,fontWeight:'800'},sub:{color:'#A6BDC1',fontSize:14,lineHeight:21},card:{backgroundColor:'#142A34',borderWidth:1,borderColor:'#28444C',borderRadius:16,padding:19,gap:12},cardTitle:{fontSize:18,fontWeight:'700',color:'#F5FAF7'},label:{color:'#F5FAF7',fontSize:13},input:{color:'#FFFFFF',backgroundColor:'#07131C',borderColor:'#31505A',borderWidth:1,borderRadius:9,padding:13},button:{backgroundColor:'#67C23A',padding:15,borderRadius:10,alignItems:'center'},buttonText:{color:'#07131C',fontWeight:'800'},error:{color:'#FF958D'},nav:{flexDirection:'row',justifyContent:'space-around',padding:14,borderTopColor:'#28444C',borderTopWidth:1},tab:{color:'#AFBDC0',fontSize:11,fontWeight:'700'}})
