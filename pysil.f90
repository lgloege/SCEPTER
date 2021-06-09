program weathering

implicit none 

integer nsp_sld,nsp_aq,nsp_gas,nrxn_ext,nz,nsld_kinspc
character(5),dimension(:),allocatable::chraq,chrsld,chrgas,chrrxn_ext,chrsld_kinspc 
real(kind=8),dimension(:),allocatable::kin_sld_spc
character(500) sim_name,runname_save,cwd,path,path2,cmd
real(kind=8) ztot,ttot,rainpowder,zsupp,poroi,satup,zsat,w,qin,p80,plant_rain,zml_ref,tc
integer count_dtunchanged_Max


CALL getcwd(cwd)
WRITE(*,*) TRIM(cwd)

call getarg(0,path)
WRITE(*,*) TRIM(path)
! call get_command_argument(0, cmd)
! WRITE(*,*) TRIM(cmd)
path2 = path(:index(path,'weathering')-2)
WRITE(*,*) TRIM(path2)

CALL chdir(TRIM(path2))
CALL getcwd(path)
WRITE(*,*) TRIM(path)

call get_variables_num( &
    & nsp_aq,nsp_sld,nsp_gas,nrxn_ext,nsld_kinspc &! output
    & )

print *,nsp_sld,nsp_aq,nsp_gas,nrxn_ext

allocate(chraq(nsp_aq),chrsld(nsp_sld),chrgas(nsp_gas),chrrxn_ext(nrxn_ext))
allocate(chrsld_kinspc(nsld_kinspc),kin_sld_spc(nsld_kinspc))
    
call get_variables( &
    & nsp_aq,nsp_sld,nsp_gas,nrxn_ext,nsld_kinspc &! input
    & ,chraq,chrgas,chrsld,chrrxn_ext,chrsld_kinspc,kin_sld_spc &! output
    & ) 
    
print *,chraq
print *,chrsld 
print *,chrgas 
print *,chrrxn_ext 
print *,chrsld_kinspc 
print *,kin_sld_spc 
! pause
sim_name = 'chkchk'

call get_bsdvalues( &
    & nz,ztot,ttot,rainpowder,zsupp,poroi,satup,zsat,zml_ref,w,qin,p80,sim_name,plant_rain,runname_save &! output
    & ,count_dtunchanged_Max,tc &
    & )
    
call weathering_main( &
    & nz,ztot,rainpowder,zsupp,poroi,satup,zsat,zml_ref,w,qin,p80,ttot,plant_rain  &! input
    & ,nsp_aq,nsp_sld,nsp_gas,nrxn_ext,chraq,chrgas,chrsld,chrrxn_ext,sim_name,runname_save &! input
    & ,count_dtunchanged_Max,tc &! input 
    & ,nsld_kinspc,chrsld_kinspc,kin_sld_spc &! input
    & )

contains 

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
 
subroutine weathering_main( &
    & nz,ztot,rainpowder,zsupp,poroi,satup0,zsat,zml_ref,w0,q0,p80,ttot,plant_rain  &! input
    & ,nsp_aq,nsp_sld,nsp_gas,nrxn_ext,chraq,chrgas,chrsld,chrrxn_ext,sim_name,runname_save &! input
    & ,count_dtunchanged_Max,tcin &! input 
    & ,nsld_kinspc_in,chrsld_kinspc_in,kin_sld_spc_in &! input 
    & )

implicit none

!-----------------------------

real(kind=8),intent(in) :: ztot != 3.0d0 ! m
real(kind=8),intent(in) :: ttot  ! yr
! real(kind=8) dz
integer,intent(in) :: nz != 30 
real(kind=8) z(nz),dz(nz)
real(kind=8),intent(in) :: tcin != 15.0d0 ! deg celsius
real(kind=8) dt  ! yr 
integer, parameter :: nt = 50000000
real(kind=8) time

real(kind=8),parameter :: rg = 8.3d-3   ! kJ mol^-1 K^-1
real(kind=8),parameter :: rg2 = 8.2d-2  ! L mol^-1 atm K^-1

real(kind=8),parameter :: tempk_0 = 273d0
real(kind=8),parameter :: sec2yr = 60d0*60d0*24d0*365d0

real(kind=8) pco2i,pnh3i,proi

real(kind=8),parameter :: n2c_g1 = 0.1d0 ! N to C ratio for OM-G1; Could be related to reactivity cf. Janssen 1996
real(kind=8),parameter :: n2c_g2 = 0.1d0
real(kind=8),parameter :: n2c_g3 = 0.1d0

real(kind=8),parameter :: fr_an_ab = 0.0d0 ! Anorthite fraction for albite (Beerling et al., 2020); 0.0 - 0.1
real(kind=8),parameter :: fr_an_olg = 0.2d0 ! Anorthite fraction for oligoclase (Beerling et al., 2020); 0.1 - 0.3
real(kind=8),parameter :: fr_an_and = 0.4d0 ! Anorthite fraction for andesine (Beerling et al., 2020); 0.3 - 0.5
real(kind=8),parameter :: fr_an_la = 0.6d0 ! Anorthite fraction for labradorite (Beerling et al., 2020); 0.5 - 0.7
real(kind=8),parameter :: fr_an_by = 0.8d0 ! Anorthite fraction for bytownite (Beerling et al., 2020); 0.7 - 0.9
real(kind=8),parameter :: fr_an_an = 1.0d0 ! Anorthite fraction for anorthite (Beerling et al., 2020); 0.9 - 1.0

real(kind=8),parameter :: fr_hb_cpx = 0.5d0 ! Hedenbergite fraction for clinopyroxene; 0.0 - 1.0
real(kind=8),parameter :: fr_fer_opx = 0.5d0 ! Ferrosilite fraction for orthopyroxene; 0.0 - 1.0
real(kind=8),parameter :: fr_fer_agt = 0.5d0 ! Ferrosilite (and Hedenbergite; or Fe/(Fe+Mg)) fraction for Augite; 0.0 - 1.0
real(kind=8),parameter :: fr_opx_agt = 0.5d0 ! OPX (or Ca/(Fe+Mg)) fraction for Augite; 0.0 - 1.0

real(kind=8),parameter :: mvka = 99.52d0 ! cm3/mol; molar volume of kaolinite; Robie et al. 1978
real(kind=8),parameter :: mvfo = 43.79d0 ! cm3/mol; molar volume of Fo; Robie et al. 1978
real(kind=8),parameter :: mvab_0 = 100.07d0 ! cm3/mol; molar volume of Ab(NaAlSi3O8); Robie et al. 1978 
real(kind=8),parameter :: mvan_0 = 100.79d0 ! cm3/mol; molar volume of An (CaAl2Si2O8); Robie et al. 1978
real(kind=8),parameter :: mvab = fr_an_ab*mvan_0 + (1d0-fr_an_ab)*mvab_0 ! cm3/mol; molar volume of albite (CaxNa(1-x)Al(1+x)Si(3-x)O8); assuming simple ('ideal'?) mixing 
real(kind=8),parameter :: mvan = fr_an_an*mvan_0 + (1d0-fr_an_an)*mvab_0 ! cm3/mol; molar volume of anorthite (CaxNa(1-x)Al(1+x)Si(3-x)O8); assuming simple ('ideal'?) mixing 
real(kind=8),parameter :: mvby = fr_an_by*mvan_0 + (1d0-fr_an_by)*mvab_0 ! cm3/mol; molar volume of bytownite (CaxNa(1-x)Al(1+x)Si(3-x)O8); assuming simple ('ideal'?) mixing 
real(kind=8),parameter :: mvla = fr_an_la*mvan_0 + (1d0-fr_an_la)*mvab_0 ! cm3/mol; molar volume of labradorite (CaxNa(1-x)Al(1+x)Si(3-x)O8); assuming simple ('ideal'?) mixing
real(kind=8),parameter :: mvand = fr_an_and*mvan_0 + (1d0-fr_an_and)*mvab_0 ! cm3/mol; molar volume of andesine (CaxNa(1-x)Al(1+x)Si(3-x)O8); assuming simple ('ideal'?) mixing
real(kind=8),parameter :: mvolg = fr_an_olg*mvan_0 + (1d0-fr_an_olg)*mvab_0 ! cm3/mol; molar volume of oligoclase (CaxNa(1-x)Al(1+x)Si(3-x)O8); assuming simple ('ideal'?) mixing
real(kind=8),parameter :: mvcc = 36.934d0 ! cm3/mol; molar volume of Cc (CaCO3); Robie et al. 1978
real(kind=8),parameter :: mvpy = 23.94d0 ! cm3/mol; molar volume of Pyrite (FeS2); Robie et al. 1978
real(kind=8),parameter :: mvgb = 31.956d0 ! cm3/mol; molar volume of Gibsite (Al(OH)3); Robie et al. 1978
real(kind=8),parameter :: mvct = 108.5d0 ! cm3/mol; molar volume of Chrysotile (Mg3Si2O5(OH)4); Robie et al. 1978
real(kind=8),parameter :: mvfa = 46.39d0 ! cm3/mol; molar volume of Fayalite (Fe2SiO4); Robie et al. 1978
real(kind=8),parameter :: mvgt = 20.82d0 ! cm3/mol; molar volume of Goethite (FeO(OH)); Robie et al. 1978
real(kind=8),parameter :: mvcabd = 129.77d0 ! cm3/mol; molar volume of Ca-beidellite (Ca(1/6)Al(7/3)Si(11/3)O10(OH)2); Wolery and Jove-Colon 2004
real(kind=8),parameter :: mvkbd = 134.15d0 ! cm3/mol; molar volume of K-beidellite (K(1/3)Al(7/3)Si(11/3)O10(OH)2); Wolery and Jove-Colon 2004
real(kind=8),parameter :: mvnabd = 130.73d0 ! cm3/mol; molar volume of Na-beidellite (Na(1/3)Al(7/3)Si(11/3)O10(OH)2); Wolery and Jove-Colon 2004
real(kind=8),parameter :: mvmgbd = 128.73d0 ! cm3/mol; molar volume of Mg-beidellite (Mg(1/6)Al(7/3)Si(11/3)O10(OH)2); Wolery and Jove-Colon 2004
real(kind=8),parameter :: mvdp = 66.09d0 ! cm3/mol; molar volume of Diopside (MgCaSi2O6);  Robie et al. 1978
real(kind=8),parameter :: mvhb = 248.09d0/3.55d0 ! cm3/mol; molar volume of Hedenbergite (FeCaSi2O6); from a webpage
real(kind=8),parameter :: mvcpx = fr_hb_cpx*mvhb + (1d0-fr_hb_cpx)*mvdp  ! cm3/mol; molar volume of clinopyroxene (FexMg(1-x)CaSi2O6); assuming simple ('ideal'?) mixing
real(kind=8),parameter :: mvkfs = 108.72d0 ! cm3/mol; molar volume of K-feldspar (KAlSi3O8); Robie et al. 1978
real(kind=8),parameter :: mvom = 30d0/1.5d0 ! cm3/mol; molar volume of OM (CH2O); calculated assuming 30 g/mol of molar weight and 1.2 g/cm3 of density (Mayer et al., 2004; Ruhlmann et al.,2006)
real(kind=8),parameter :: mvomb = 30d0/1.5d0 ! cm3/mol; assumed to be same as mvom
real(kind=8),parameter :: mvg1 = 30d0/1.5d0 ! cm3/mol; assumed to be same as mvom
real(kind=8),parameter :: mvg2 = 30d0/1.5d0 ! cm3/mol; assumed to be same as mvom
real(kind=8),parameter :: mvg3 = 30d0/1.5d0 ! cm3/mol; assumed to be same as mvom
real(kind=8),parameter :: mvamsi = 25.739d0 ! cm3/mol; molar volume of amorphous silica taken as cristobalite (SiO2); Robie et al. 1978
real(kind=8),parameter :: mvarg = 34.15d0 ! cm3/mol; molar volume of aragonite; Robie et al. 1978
real(kind=8),parameter :: mvdlm = 64.34d0 ! cm3/mol; molar volume of dolomite; Robie et al. 1978
real(kind=8),parameter :: mvhm = 30.274d0 ! cm3/mol; molar volume of hematite; Robie et al. 1978
real(kind=8),parameter :: mvill = 139.35d0 ! cm3/mol; molar volume of illite (K0.6Mg0.25Al2.3Si3.5O10(OH)2); Wolery and Jove-Colon 2004
real(kind=8),parameter :: mvanl = 97.49d0 ! cm3/mol; molar volume of analcime (NaAlSi2O6*H2O); Robie et al. 1978
real(kind=8),parameter :: mvnph = 54.16d0 ! cm3/mol; molar volume of nepheline (NaAlSiO4); Robie et al. 1978
real(kind=8),parameter :: mvqtz = 22.688d0 ! cm3/mol; molar volume of quartz (SiO2); Robie et al. 1978
real(kind=8),parameter :: mvgps = 74.69d0 ! cm3/mol; molar volume of gypsum (CaSO4*2H2O); Robie et al. 1978
real(kind=8),parameter :: mvtm = 272.92d0 ! cm3/mol; molar volume of tremolite (Ca2Mg5(Si8O22)(OH)2); Robie et al. 1978
real(kind=8),parameter :: mven = 31.31d0 ! cm3/mol; molar volume of enstatite (MgSiO3); Robie and Hemingway 1995
real(kind=8),parameter :: mvfer = 33.00d0 ! cm3/mol; molar volume of ferrosilite (FeSiO3); Robie and Hemingway 1995
real(kind=8),parameter :: mvopx = fr_fer_opx*mvfer +(1d0-fr_fer_opx)*mven !  cm3/mol; molar volume of clinopyroxene (FexMg(1-x)SiO3); assuming simple ('ideal'?) mixing
real(kind=8),parameter :: mvmscv = 140.71d0 ! cm3/mol; molar volume of muscovite (KAl2(AlSi3O10)(OH)2); Robie et al. 1978
real(kind=8),parameter :: mvplgp = 149.91d0 ! cm3/mol; molar volume of phlogopite (KMg3(AlSi3O10)(OH)2); Robie et al. 1978
real(kind=8),parameter :: mvantp = 274.00d0 ! cm3/mol; molar volume of anthophyllite (Mg7Si8O22(OH)2); Robie and Bethke 1962
real(kind=8),parameter :: mvagt = (fr_fer_agt*mvfer +(1d0-fr_fer_agt)*mven)*2d0*fr_opx_agt &! (Fe2xyMg2(1-x)ySi2yO6y)
                                & + (fr_fer_agt*mvhb + (1d0-fr_fer_agt)*mvdp)*(1d0-fr_opx_agt) ! (Fex(1-y)Mg(1-x)(1-y)Ca(1-y)Si2(1-y)O6(1-y))
                                !  cm3/mol; molar volume of augite 
                                ! (Fe(2xy+x(1-y))Mg(2y-2xy+1+xy-x-y)Ca(1-y)Si2O6 = Fe(xy+x)Mg(y-xy+1-x)Ca(1-y)Si2O6)
                                ! ; assuming simple ('ideal'?) mixing
                                
real(kind=8),parameter :: mwtka = 258.162d0 ! g/mol; formula weight of Ka; Robie et al. 1978
real(kind=8),parameter :: mwtfo = 140.694d0 ! g/mol; formula weight of Fo; Robie et al. 1978
real(kind=8),parameter :: mwtab_0 = 262.225d0 ! g/mol; formula weight of Ab; Robie et al. 1978
real(kind=8),parameter :: mwtan_0 = 278.311d0 ! g/mol; formula weight of An; Robie et al. 1978
real(kind=8),parameter :: mwtab = fr_an_ab*mwtan_0 + (1d0-fr_an_ab)*mwtab_0 ! g/mol; formula weight of albte (CaxNa(1-x)Al(1+x)Si(3-x)O8); assuming simple ('ideal'?) mixing
real(kind=8),parameter :: mwtan = fr_an_an*mwtan_0 + (1d0-fr_an_an)*mwtab_0 ! g/mol; formula weight of anorthite (CaxNa(1-x)Al(1+x)Si(3-x)O8); assuming simple ('ideal'?) mixing
real(kind=8),parameter :: mwtby = fr_an_by*mwtan_0 + (1d0-fr_an_by)*mwtab_0 ! g/mol; formula weight of bytownite (CaxNa(1-x)Al(1+x)Si(3-x)O8); assuming simple ('ideal'?) mixing
real(kind=8),parameter :: mwtla = fr_an_la*mwtan_0 + (1d0-fr_an_la)*mwtab_0 ! g/mol; formula weight of labradorite (CaxNa(1-x)Al(1+x)Si(3-x)O8); assuming simple ('ideal'?) mixing
real(kind=8),parameter :: mwtand = fr_an_and*mwtan_0 + (1d0-fr_an_and)*mwtab_0 ! g/mol; formula weight of andesine (CaxNa(1-x)Al(1+x)Si(3-x)O8); assuming simple ('ideal'?) mixing
real(kind=8),parameter :: mwtolg = fr_an_olg*mwtan_0 + (1d0-fr_an_olg)*mwtab_0 ! g/mol; formula weight of oligoclase (CaxNa(1-x)Al(1+x)Si(3-x)O8); assuming simple ('ideal'?) mixing
real(kind=8),parameter :: mwtcc = 100.089d0 ! g/mol; formula weight of Cc; Robie et al. 1978
real(kind=8),parameter :: mwtpy = 119.967d0 ! g/mol; formula weight of Py; Robie et al. 1978
real(kind=8),parameter :: mwtgb = 78.004d0 ! g/mol; formula weight of Gb; Robie et al. 1978
real(kind=8),parameter :: mwtct = 277.113d0 ! g/mol; formula weight of Ct; Robie et al. 1978
real(kind=8),parameter :: mwtfa = 203.778d0 ! g/mol; formula weight of Fa; Robie et al. 1978
real(kind=8),parameter :: mwtgt = 88.854d0 ! g/mol; formula weight of Gt; Robie et al. 1978
real(kind=8),parameter :: mwtcabd = 366.6252667d0 ! g/mol; formula weight of Cabd calculated from atmoic weight
real(kind=8),parameter :: mwtkbd = 372.9783667d0 ! g/mol; formula weight of Kbd calculated from atmoic weight
real(kind=8),parameter :: mwtnabd = 367.6088333d0 ! g/mol; formula weight of Nabd calculated from atmoic weight
real(kind=8),parameter :: mwtmgbd = 363.9964333d0 ! g/mol; formula weight of Mgbd calculated from atmoic weight
real(kind=8),parameter :: mwtdp = 216.553d0 ! g/mol;  Robie et al. 1978
real(kind=8),parameter :: mwthb = 248.09d0 ! g/mol; from a webpage
real(kind=8),parameter :: mwtcpx = fr_hb_cpx*mwthb + (1d0-fr_hb_cpx)*mwtdp ! g/mol; formula weight of clinopyroxene (FexMg(1-x)CaSi2O6); assuming simple ('ideal'?) mixing
real(kind=8),parameter :: mwtkfs = 278.33d0 ! g/mol; formula weight of Kfs; Robie et al. 1978
real(kind=8),parameter :: mwtom = 30d0 ! g/mol; formula weight of CH2O
real(kind=8),parameter :: mwtomb = 30d0 ! g/mol; formula weight of CH2O
real(kind=8),parameter :: mwtg1 = 30d0 ! g/mol; formula weight of CH2O
real(kind=8),parameter :: mwtg2 = 30d0 ! g/mol; formula weight of CH2O
real(kind=8),parameter :: mwtg3 = 30d0 ! g/mol; formula weight of CH2O
real(kind=8),parameter :: mwtamsi = 60.085d0 ! g/mol; formula weight of amorphous silica
real(kind=8),parameter :: mwtarg = 100.089d0 ! g/mol; formula weight of aragonite
real(kind=8),parameter :: mwtdlm = 184.403d0 ! g/mol; formula weight of dolomite
real(kind=8),parameter :: mwthm = 159.692d0 ! g/mol; formula weight of hematite
real(kind=8),parameter :: mwtill = 383.90053d0 ! g/mol; formula weight of Ill calculated from atmoic weight
real(kind=8),parameter :: mwtanl = 220.155d0 ! g/mol; formula weight of analcime
real(kind=8),parameter :: mwtnph = 142.055d0 ! g/mol; formula weight of nepheline
real(kind=8),parameter :: mwtqtz = 60.085d0 ! g/mol; formula weight of quartz
real(kind=8),parameter :: mwtgps = 172.168d0 ! g/mol; formula weight of gypsum
real(kind=8),parameter :: mwttm = 812.374d0 ! g/mol; formula weight of tremolite
real(kind=8),parameter :: mwten = 100.389d0 ! g/mol; formula weight of enstatite
real(kind=8),parameter :: mwtfer = 131.931d0 ! g/mol; formula weight of ferrosilite
real(kind=8),parameter :: mwtopx = fr_fer_opx*mwtfer + (1d0 -fr_fer_opx)*mwten ! g/mol; formula weight of clinopyroxene (FexMg(1-x)SiO3); assuming simple ('ideal'?) mixing
real(kind=8),parameter :: mwtmscv = 398.311d0 ! g/mol; formula weight of muscovite
real(kind=8),parameter :: mwtplgp = 417.262d0 ! g/mol; formula weight of phlogopite
real(kind=8),parameter :: mwtantp = 780.976d0 ! g/mol; formula weight of anthophyllite
real(kind=8),parameter :: mwtagt = (fr_fer_agt*mwtfer +(1d0-fr_fer_agt)*mwten)*2d0*fr_opx_agt &! (Fe2xyMg2(1-x)ySi2yO6y)
                                & + (fr_fer_agt*mwthb + (1d0-fr_fer_agt)*mwtdp)*(1d0-fr_opx_agt) ! (Fex(1-y)Mg(1-x)(1-y)Ca(1-y)Si2(1-y)O6(1-y))
                                !  g/mol; formula weight of augite 
                                ! (Fe(2xy+x(1-y))Mg(2y-2xy+1+xy-x-y)Ca(1-y)Si2O6 = Fe(xy+x)Mg(y-xy+1-x)Ca(1-y)Si2O6)
                                ! ; assuming simple ('ideal'?) mixing
                                
real(kind=8) :: rho_grain = 2.7d0 ! g/cm3 as soil grain density 
real(kind=8) :: rho_grain_calc,rho_grain_calcx != 2.7d0 ! g/cm3 as soil grain density 
real(kind=8) :: rho_grain_z(nz),sldvolfrac(nz) != 2.7d0 ! g/cm3 as soil grain density 
real(kind=8) :: rho_error,rho_tol, poroi_calc 

real(kind=8),parameter :: mvblk = mvka ! for bulk soil assumed to be equal to kaolinite
real(kind=8),parameter :: mwtblk = mwtka
real(kind=8) :: mblk(nz),mblki,mblkix,mblkx(nz)
logical(kind=8) :: incld_blk

! real(kind=8)::plant_rain = 1.4d-3 ! g C/g soil/yr; converted from 1.6d-4 mg C / g soil /hr from Georgiou et al. 2017 ! 
real(kind=8),intent(in)::plant_rain != 1d2 ! 1 t/ha/yr; approximate values from Vanveen et al. 1991 ! 
! real(kind=8)::plant_rain = 0.1d2 ! 

real(kind=8)::zsupp_plant = 0.3d0 !  e-folding decrease

! real(kind=8)::rainpowder = 40d2 !  g/m2/yr corresponding to 40 t/ha/yr (40x1e3x1e3/1e4)
! real(kind=8)::rainpowder = 0.5d2 !  g/m2/yr corresponding to 0.5 t/ha/yr (0.5x1e3x1e3/1e4)
real(kind=8),intent(in)::rainpowder != 30d2 !  g/m2/yr 
! real(kind=8)::rainpowder = 10d2 !  g/m2/yr corresponding to 10 t/ha/yr (0.5x1e3x1e3/1e4)


real(kind=8),intent(in)::zsupp != 0.3d0 !  e-folding decrease

real(kind=8) sat(nz), poro(nz), torg(nz), tora(nz), tc, satup

! real(kind=8) :: poroi = 0.1d0 !*** default
real(kind=8),intent(in) :: poroi != 0.5d0

real(kind=8),intent(in) :: satup0 != 0.10d0

! real(kind=8) :: zsat = 30d0  ! water table depth [m] ** default 
real(kind=8),intent(in) :: zsat != 5d0  ! water table depth [m] 
! real(kind=8) :: zsat = 15d0

real(kind=8),intent(in) :: w0 != 5.0d-5 ! m yr^-1, uplift rate ** default 
! real(kind=8), parameter :: w = 1.0d-4 ! m yr^-1, uplift rate
real(kind=8) w(nz),w_btm,wx(nz),ssa(nz),wexp(nz)

! real(kind=8) :: qin = 1d-1 ! m yr^-1, advection (m3 water / m2 profile / yr)  ** default
real(kind=8),intent(in) :: q0 != 10d-1 ! m yr^-1
! real(kind=8) :: qin = 0.1d-1 ! m yr^-1 
real(kind=8) v(nz),qin

! real(kind=8) :: hr = 1d5 ! m^2 m^-3, reciprocal of hydraulic radius  ** default 
! real(kind=8) :: hr = 1d4 ! m^2 m^-3, reciprocal of hydraulic radius
real(kind=8) :: hrii = 1d5

! real(kind=8) :: p80 = 10d-6 ! m (**default?)
real(kind=8),intent(in) :: p80 != 1d-6 ! m 

! real(kind=8) ssa_cmn,mvab_save,mvan_save,mvcc_save,mvfo_save,mvka_save,mvgb_save
real(kind=8),dimension(nz):: pro,prox,poroprev,hr,rough,hri,hrprev,vprev,torgprev,toraprev,wprev
real(kind=8),dimension(nz):: dummy,up,dwn,cnr,adf
real(kind=8) :: rough_c0 = 10d0**(3.3d0)
real(kind=8) :: rough_c1 = 0.33d0

real(kind=8) kho,ucv,kco2,k1,kw,k2,khco2i,knh3,k1nh3,khnh3i,kn2o

integer iz,it,ispa,ispg,isps,irxn,ispa2,ispg2,isps2,ico2,ph_iter,isps_kinspc

real(kind=8) error 
real(kind=8) :: tol = 1d-6

! integer, parameter :: nrec = 22
integer, parameter :: nrec = 20
real(kind=8) rectime(nrec)
character(3) chr
character(256) runname,workdir, chrz(3), chrq(3),base,fname, chrrain, cwd,flxdir, profdir
character(500),intent(in):: runname_save
character(500) loc_runname_save
integer irec, iter


integer  iflx
! real(kind=8) :: maxdt = 10d0
real(kind=8) :: maxdt = 0.2d0 ! for basalt exp?

real(kind=8) :: maxdt_max = 1d2  ! default   
! real(kind=8) :: maxdt_max = 1d0   ! when time step matters a reduced value might work 

logical :: pre_calc = .false.
! logical :: pre_calc = .true.

logical :: read_data = .false.
! logical :: read_data = .true.

! logical :: incld_rough = .false.
logical :: incld_rough = .true.

! logical :: cplprec = .false.
logical :: cplprec = .true.

logical :: dust_wave = .false.
! logical :: dust_wave = .true.

logical :: al_inhibit = .false.
! logical :: al_inhibit = .true.

logical :: timestep_fixed = .false.
! logical :: timestep_fixed = .true.

! logical :: no_biot = .false.
logical :: no_biot = .true.

logical :: biot_fick = .false.
! logical :: biot_fick = .true.

logical :: biot_turbo2 = .false.
! logical :: biot_turbo2 = .true.

logical :: biot_labs = .false.
! logical :: biot_labs = .true.

logical :: biot_till = .false.
! logical :: biot_till = .true.

! logical :: display = .false.
logical :: display = .true.

! logical :: regular_grid = .false.
logical :: regular_grid = .true.

! logical :: method_precalc = .false.
logical :: method_precalc = .true.

! logical :: sld_enforce = .false.
logical :: sld_enforce = .true.

logical :: poroevol = .false.

logical :: surfevol1 = .false.
logical :: surfevol2 = .false.

! logical :: noncnstw = .false. ! constant uplift rate 
logical :: noncnstw = .true.  ! varied with porosity

logical :: display_lim = .false. ! limiting display fluxes and concs. 
! logical :: display_lim = .true.

logical :: dust_step = .false.
! logical :: dust_step = .true.

logical,dimension(3) :: climate != .false.
! logical,dimension(3) :: climate != .true.

real(kind=8) :: step_tau = 0.1d0 ! yr time duration during which dust is added
real(kind=8) :: tol_step_tau = 1d-6 ! yr time duration during which dust is added

real(kind=8) :: wave_tau = 2d0 ! yr periodic time for wave 
real(kind=8) :: dust_norm = 0d0
real(kind=8) :: dust_norm_prev = 0d0

real(kind=8),dimension(:,:),allocatable :: clim_T,clim_q,clim_sat
real(kind=8),dimension(3) :: dct,ctau
integer iclim,ict
integer,dimension(3)::nclim,ict_prev
logical,dimension(3)::ict_change
character(50),dimension(3) :: clim_file

! type of uplift vs porosity relationship
! #ifndef iwtypein 
! #define iwtypein  0
! #endif 
integer iwtype 
! parameter(iwtype = iwtypein)
integer,parameter :: iwtype_cnst = 0
integer,parameter :: iwtype_pwcnst = 1
integer,parameter :: iwtype_spwcnst = 2
integer,parameter :: iwtype_flex = 3

integer imixtype 
integer,parameter :: imixtype_nobio = 0
integer,parameter :: imixtype_fick = 1
integer,parameter :: imixtype_turbo2 = 2
integer,parameter :: imixtype_till = 3
integer,parameter :: imixtype_labs = 4

logical display_lim_in !  defining whether limiting display or not  (input from input file swtiches.in)
logical poroiter_in !  true if porosity (or w) is iteratively checked  (input from input file swtiches.in)

data rectime /1d1,3d1,1d2,3d2,1d3,3d3,1d4,3d4 &
    & ,1d5,2d5,3d5,4d5,5d5,6d5,7d5,8d5,9d5,1d6,1.1d6,1.2d6/
! data rectime /-1d6,0d6,1d6,2d6,3d6,4d6,5d6,6d6,7d6,8d6
! &,9d6,10d6,11d6,12d6,13d6,14d6,15d6,16d6,17d6,18d6,19d6,20d6/
! data rectime /21d6,22d6,23d6,24d6,25d6,26d6,27d6,28d6,29d6,30d6
! & ,31d6,32d6,33d6,34d6,35d6,36d6,37d6,38d6,39d6,40d6,41d6,42d6/
real(kind=8) :: savetime = 1d3
real(kind=8) :: dsavetime = 1d3


integer poro_iter , poro_iter_max
real(kind=8) poro_error, poro_tol, porox(nz), dwsporo(nz), wsporo(nz) 

real(kind=8) beta 

logical :: flgback = .false.
logical :: flgreducedt = .false.
logical :: flgreducedt_prev = .false.

real(kind=8) time_start, time_fin, progress_rate, progress_rate_prev
integer count_dtunchanged  
integer,intent(in):: count_dtunchanged_Max  

integer,intent(in)::nsp_sld != 5
#ifdef diss_only
integer,parameter::nsp_sld_2 = 0
#else
integer,parameter::nsp_sld_2 = 17
#endif 
integer,parameter::nsp_sld_all = 44
integer ::nsp_sld_cnst != nsp_sld_all - nsp_sld
integer,intent(in)::nsp_aq != 5
integer,parameter::nsp_aq_ph = 10
integer,parameter::nsp_aq_all = 10
integer ::nsp_aq_cnst != nsp_aq_all - nsp_aq
integer,intent(in)::nsp_gas != 2
integer,parameter::nsp_gas_ph = 2
integer,parameter::nsp_gas_all = 4
integer ::nsp_gas_cnst != nsp_gas_all - nsp_gas
integer ::nsp3 != nsp_sld + nsp_aq + nsp_gas
integer,intent(in)::nrxn_ext != 1
integer,parameter::nrxn_ext_all = 9
integer :: nflx ! = 5 + nrxn_ext + nsp_sld  
integer,intent(in)::nsld_kinspc_in
integer :: nsld_kinspc,nsld_kinspc_add
character(5),dimension(nsp_sld),intent(in)::chrsld
character(5),dimension(nsp_sld_2)::chrsld_2
character(5),dimension(nsp_sld_all)::chrsld_all
character(5),dimension(nsp_sld_all - nsp_sld)::chrsld_cnst
character(5),dimension(nsp_aq),intent(in)::chraq
character(5),dimension(nsp_aq_ph)::chraq_ph
character(5),dimension(nsp_aq_all)::chraq_all
character(5),dimension(nsp_aq_all - nsp_aq)::chraq_cnst
character(5),dimension(nsp_gas),intent(in)::chrgas
character(5),dimension(nsp_gas_ph)::chrgas_ph
character(5),dimension(nsp_gas_all)::chrgas_all
character(5),dimension(nsp_gas_all - nsp_gas)::chrgas_cnst
character(5),dimension(nrxn_ext),intent(in)::chrrxn_ext
character(5),dimension(nrxn_ext_all)::chrrxn_ext_all
character(5),dimension(nsld_kinspc_in),intent(in)::chrsld_kinspc_in
character(5),dimension(:),allocatable ::chrsld_kinspc
real(kind=8),dimension(nsp_sld)::msldi,msldth,mv,rfrc_sld,mwt,rfrc_sld_plant
real(kind=8),dimension(nsp_sld,nsp_aq)::staq
real(kind=8),dimension(nsp_sld,nsp_gas)::stgas
real(kind=8),dimension(nsp_sld,nz)::msldx,msld,ksld,omega,msldsupp,nonprec,rxnsld
real(kind=8),dimension(nsp_sld,5 + nrxn_ext + nsp_sld,nz)::flx_sld
real(kind=8),dimension(nsp_aq)::maqi,maqth,daq
real(kind=8),dimension(nsp_aq,nz)::maqx,maq,rxnaq,maqsupp
real(kind=8),dimension(nsp_aq,5 + nrxn_ext + nsp_sld,nz)::flx_aq
real(kind=8),dimension(nsp_gas)::mgasi,mgasth,dgasa,dgasg,dmgas,khgasi,dgasi
real(kind=8),dimension(nsp_gas,nz)::mgasx,mgas,khgasx,khgas,dgas,agasx,agas,rxngas,mgassupp 
real(kind=8),dimension(nsp_gas,5 + nrxn_ext + nsp_sld,nz)::flx_gas 
real(kind=8),dimension(nrxn_ext,nz)::rxnext
real(kind=8),dimension(nrxn_ext,nsp_gas)::stgas_ext,stgas_dext
real(kind=8),dimension(nrxn_ext,nsp_aq)::staq_ext,staq_dext
real(kind=8),dimension(nrxn_ext,nsp_sld)::stsld_ext,stsld_dext
real(kind=8),dimension(nsld_kinspc_in),intent(in)::kin_sld_spc_in
real(kind=8),dimension(:),allocatable::kin_sld_spc

real(kind=8),dimension(nsp_aq_all)::daq_all,maqi_all,maqth_all
real(kind=8),dimension(nsp_gas_all)::dgasa_all,dgasg_all,mgasi_all,mgasth_all
real(kind=8),dimension(nsp_gas_all,3)::keqgas_h
real(kind=8),dimension(nsp_aq_all,4)::keqaq_h
real(kind=8),dimension(nsp_aq_all,2)::keqaq_c
real(kind=8),dimension(nsp_aq_all,2)::keqaq_s
real(kind=8),dimension(nsp_aq_all,2)::keqaq_no3
real(kind=8),dimension(nsp_aq_all,2)::keqaq_nh3
real(kind=8),dimension(nsp_sld_all,nz)::ksld_all
real(kind=8),dimension(nsp_sld_all,nsp_aq_all)::staq_all
real(kind=8),dimension(nsp_sld_all,nsp_gas_all)::stgas_all
real(kind=8),dimension(nsp_sld_all)::keqsld_all,mv_all,msldi_all,msldth_all,rfrc_sld_all,mwt_all,rfrc_sld_plant_all,msldi_allx
real(kind=8),dimension(nrxn_ext_all,nz)::krxn1_ext_all
real(kind=8),dimension(nrxn_ext_all,nz)::krxn2_ext_all
real(kind=8),dimension(nrxn_ext_all,nsp_aq_all)::staq_ext_all,staq_dext_all
real(kind=8),dimension(nrxn_ext_all,nsp_gas_all)::stgas_ext_all,stgas_dext_all
real(kind=8),dimension(nrxn_ext_all,nsp_sld_all)::stsld_ext_all,stsld_dext_all

real(kind=8),dimension(nsp_aq_all,nz)::dprodmaq_all,dso4fdmaq_all
real(kind=8),dimension(nsp_gas_all,nz)::dprodmgas_all,dso4fdmgas_all

real(kind=8),dimension(nsp_aq_all - nsp_aq,nz)::maqc
real(kind=8),dimension(nsp_gas_all - nsp_gas,nz)::mgasc
real(kind=8),dimension(nsp_sld_all - nsp_sld,nz)::msldc

real(kind=8),dimension(4,5 + nrxn_ext + nsp_sld,nz)::flx_co2sp
character(5),dimension(6)::chrco2sp

! an attempt to record psd
integer,parameter :: nps = 50 ! bins for particle size 
! real(kind=8),parameter :: ps_min = 0.1d-6 ! min particle size (0.1 um)
real(kind=8),parameter :: ps_min = 10d-9 ! min particle size (10 nm)
real(kind=8),parameter :: ps_max = 10d-3 ! max particle size (10 mm)
real(kind=8),parameter :: pi = 4d0*atan(1d0) ! 
! real(kind=8),parameter :: psd_th = 1d-3 ! 
real(kind=8),parameter :: psd_th = 1d0 ! 
real(kind=8),dimension(nps)::ps
real(kind=8),dimension(nps,nz)::psd,dVd,psd_old,dpsd,psdx
real(kind=8),dimension(nps,nz)::psd_rain
real(kind=8),dimension(nps,nz)::psd_norm,psdx_norm,dpsd_norm,psd_rain_norm
real(kind=8),dimension(nps)::psd_tmp,dvd_tmp
real(kind=8),dimension(nps)::psd_pr,dps
real(kind=8),dimension(nps)::psd_pr_norm,psd_norm_fact
real(kind=8),dimension(nz)::DV
integer,parameter :: nps_rain_char = 4
real(kind=8),dimension(nps_rain_char)::pssigma_rain_list,psu_rain_list 
real(kind=8) psu_pr,pssigma_pr,psu_rain,pssigma_rain,ps_new,ps_newp,dvd_res,error_psd
real(kind=8) :: ps_sigma_std = 1d0
! real(kind=8) :: ps_sigma_std = 0.2d0
integer ips,iips,ips_new
logical psd_error_flg
integer,parameter :: nflx_psd = 6
real(kind=8),dimension(nps,nflx_psd,nz) :: flx_psd ! itflx,iadv,idif,irain,irxn,ires
real(kind=8),dimension(nps,nflx_psd,nz) :: flx_psd_norm ! itflx,iadv,idif,irain,irxn,ires
! logical :: do_psd = .false.
logical :: do_psd = .true.
! logical :: do_psd_norm = .true.
logical :: do_psd_norm = .false.


integer ieqgas_h0,ieqgas_h1,ieqgas_h2
data ieqgas_h0,ieqgas_h1,ieqgas_h2/1,2,3/

integer ieqaq_h1,ieqaq_h2,ieqaq_h3,ieqaq_h4
data ieqaq_h1,ieqaq_h2,ieqaq_h3,ieqaq_h4/1,2,3,4/

integer ieqaq_co3,ieqaq_hco3
data ieqaq_co3,ieqaq_hco3/1,2/

integer ieqaq_so4,ieqaq_so42
data ieqaq_so4,ieqaq_so42/1,2/

#ifdef full_flux_report
integer,dimension(nsp_aq,nz)::iaqflx
integer,dimension(nsp_gas,nz)::igasflx
integer,dimension(nsp_sld,nz)::isldflx
integer,dimension(6,nz)::ico2flx
#else
integer,dimension(nsp_aq)::iaqflx
integer,dimension(nsp_gas)::igasflx
integer,dimension(nsp_sld)::isldflx
integer,dimension(6)::ico2flx
#endif 

integer,parameter::idust = 15
integer isldprof,isldprof2,isldprof3,iaqprof,igasprof,isldsat,ibsd,irate,ipsd,ipsdv,ipsds,ipsdflx 

logical,dimension(nsp_sld)::turbo2,labs,nonlocal,nobio,fick,till
real(kind=8),dimension(nz,nz,nsp_sld)::trans
real(kind=8),intent(in)::zml_ref
real(kind=8) dbl_ref
integer izml
integer :: nz_disp = 10

real(kind=8),dimension(nz)::so4f,no3f,so4fprev

real(kind=8) dt_prev

logical print_cb,ph_error,save_trans
character(500) print_loc
character(500),intent(in):: sim_name

real(kind=8) def_dust,def_rain,def_pr,def_OM_frc
character(5),dimension(5 + nrxn_ext + nsp_sld)::chrflx
character(3) chriz
character(50) chrfmt

integer::itflx,iadv,idif,irain,ires
data itflx,iadv,idif,irain/1,2,3,4/

integer,dimension(nsp_sld)::irxn_sld 
integer,dimension(nrxn_ext)::irxn_ext

integer nsp_aq_save,nsp_sld_save,nsp_gas_save,nrxn_ext_save,nsld_kinspc_save 
character(5),dimension(:),allocatable::chraq_save,chrsld_save,chrgas_save,chrrxn_ext_save &
    & ,chrsld_kinspc_save
real(kind=8),dimension(:,:),allocatable::msld_save,mgas_save,maq_save
real(kind=8),dimension(:),allocatable::kin_sldspc_save

integer t1,t2,t_rate,t_max,diff
! character(3):: msldunit = 'sld '
character(3):: msldunit = 'blk'
real(kind=8) ucvsld1,ucvsld2
!-------------------------

tc = tcin
qin = q0
satup = satup0

nsp_sld_cnst = nsp_sld_all - nsp_sld
nsp_aq_cnst = nsp_aq_all - nsp_aq
nsp_gas_cnst = nsp_gas_all - nsp_gas
nsp3 = nsp_sld + nsp_aq + nsp_gas

#ifdef calcw_full
nsp3 = nsp3 + 1
#endif 

isldprof = idust + nsp_sld + nsp_gas + nsp_aq + 1
isldprof2 = idust + nsp_sld + nsp_gas + nsp_aq + 2
isldprof3 = idust + nsp_sld + nsp_gas + nsp_aq + 3
iaqprof = idust + nsp_sld + nsp_gas + nsp_aq + 4
igasprof = idust + nsp_sld + nsp_gas + nsp_aq + 5
isldsat = idust + nsp_sld + nsp_gas + nsp_aq + 6
ibsd = idust + nsp_sld + nsp_gas + nsp_aq + 7
irate = idust + nsp_sld + nsp_gas + nsp_aq + 8
ipsd = idust + nsp_sld + nsp_gas + nsp_aq + 9
ipsdv = idust + nsp_sld + nsp_gas + nsp_aq + 10
ipsds = idust + nsp_sld + nsp_gas + nsp_aq + 11
ipsdflx = idust + nsp_sld + nsp_gas + nsp_aq + 12

nflx = 5 + nrxn_ext + nsp_sld

do isps=1,nsp_sld
    irxn_sld(isps) = 4+isps
enddo 

do irxn=1,nrxn_ext
    irxn_ext(irxn) = 4+nsp_sld+irxn
enddo 

ires = nflx

chrflx(1:4) = (/'tflx ','adv  ','dif  ','rain '/)
if (nsp_sld > 0) chrflx(irxn_sld(:)) = chrsld
if (nrxn_ext > 0) chrflx(irxn_ext(:)) = chrrxn_ext
chrflx(nflx) = 'res  '

! print *,chrflx,irxn_sld,chrsld

! pause

! define all species and rxns definable in the model 
! note that rxns here exclude diss(/prec) of mineral 
! which are automatically included when associated mineral is chosen

chrsld_all = (/'fo   ','ab   ','an   ','cc   ','ka   ','gb   ','py   ','ct   ','fa   ','gt   ','cabd ' &
    & ,'dp   ','hb   ','kfs  ','om   ','omb  ','amsi ','arg  ','dlm  ','hm   ','ill  ','anl  ','nph  ' &
    & ,'qtz  ','gps  ','tm   ','la   ','by   ','olg  ','and  ','cpx  ','en   ','fer  ','opx  ','kbd  ' &
    & ,'mgbd ','nabd ','mscv ','plgp ','antp ','agt  ' &
    & ,'g1   ','g2   ','g3   '/)
chraq_all = (/'mg   ','si   ','na   ','ca   ','al   ','fe2  ','fe3  ','so4  ','k    ','no3  '/)
chrgas_all = (/'pco2 ','po2  ','pnh3 ','pn2o '/)
chrrxn_ext_all = (/'resp ','fe2o2','omomb','ombto','pyfe3','amo2o','g2n0 ','g2n21','g2n22'/)

! define the species and rxns explicitly simulated in the model in a fully coupled way
! should be chosen from definable species & rxn lists above 

! chrsld = (/'fo   ','ab   ','an   ','cc   ','ka   '/)
! chraq = (/'mg   ','si   ','na   ','ca   ','al   '/)
! chrgas = (/'pco2 ','po2  '/)
! chrrxn_ext = (/'resp '/)


! define solid species which can precipitate
! in default, all minerals only dissolve 
! should be chosen from the chrsld list
#ifdef diss_only
chrsld_2(:) = '     '
#else
chrsld_2 = (/'cc   ','ka   ','gb   ','ct   ','gt   ','cabd ','amsi ','hm   ','ill  ','anl  ','gps  '  &
    ,'arg  ','dlm  ','qtz  ','mgbd ','nabd ','kbd  '/) 
#endif 
! below are species which are sensitive to pH 
chraq_ph = (/'mg   ','si   ','na   ','ca   ','al   ','fe2  ','fe3  ','so4  ','k    ','no3  '/)
chrgas_ph = (/'pco2 ','pnh3 '/)

chrco2sp = (/'co2g ','co2aq','hco3 ','co3  ','DIC  ','ALK  '/)

if (nsp_aq_cnst .ne. 0) then 
    do ispa = 1, nsp_aq_cnst
        do ispa2=1,nsp_aq_all
            if (.not.any(chraq==chraq_all(ispa2)) .and. .not.any(chraq_cnst==chraq_all(ispa2))) then 
                chraq_cnst(ispa) = chraq_all(ispa2)
                exit 
            endif 
        enddo
    enddo 
    print *, chraq_cnst
    ! pause
endif 

if (nsp_gas_cnst .ne. 0) then 
    do ispg = 1, nsp_gas_cnst
        do ispg2=1,nsp_gas_all
            if (.not.any(chrgas==chrgas_all(ispg2)) .and. .not.any(chrgas_cnst==chrgas_all(ispg2))) then 
                chrgas_cnst(ispg) = chrgas_all(ispg2)
                exit 
            endif 
        enddo
    enddo 
    print *, chrgas_cnst
    ! pause 
endif 

if (nsp_sld_cnst .ne. 0) then 
    do isps = 1, nsp_sld_cnst
        do isps2=1,nsp_sld_all
            if (.not.any(chrsld==chrsld_all(isps2)) .and. .not.any(chrsld_cnst==chrsld_all(isps2))) then 
                chrsld_cnst(isps) = chrsld_all(isps2)
                exit 
            endif 
        enddo
    enddo 
    print *, chrsld_cnst
    ! pause 
endif 

! molar volume 

mv_all = (/mvfo,mvab,mvan,mvcc,mvka,mvgb,mvpy,mvct,mvfa,mvgt,mvcabd,mvdp,mvhb,mvkfs,mvom,mvomb,mvamsi &
    & ,mvarg,mvdlm,mvhm,mvill,mvanl,mvnph,mvqtz,mvgps,mvtm,mvla,mvby,mvolg,mvand,mvcpx,mven,mvfer,mvopx &
    & ,mvkbd,mvmgbd,mvnabd,mvmscv,mvplgp,mvantp,mvagt &
    & ,mvg1,mvg2,mvg3/)
mwt_all = (/mwtfo,mwtab,mwtan,mwtcc,mwtka,mwtgb,mwtpy,mwtct,mwtfa,mwtgt,mwtcabd,mwtdp,mwthb,mwtkfs,mwtom,mwtomb,mwtamsi &
    & ,mwtarg,mwtdlm,mwthm,mwtill,mwtanl,mwtnph,mwtqtz,mwtgps,mwttm,mwtla,mwtby,mwtolg,mwtand,mwtcpx,mwten,mwtfer,mwtopx &
    & ,mwtkbd,mwtmgbd,mwtnabd,mwtmscv,mwtplgp,mwtantp,mwtagt &
    & ,mwtg1,mwtg2,mwtg3/)

do isps = 1, nsp_sld 
    mv(isps) = mv_all(findloc(chrsld_all,chrsld(isps),dim=1))
    mwt(isps) = mwt_all(findloc(chrsld_all,chrsld(isps),dim=1))
enddo 

! maqi_all = 0d0
    
def_rain = 1d-20
def_pr = 1d-20
    
call get_rainwater( &
    & nsp_aq_all,chraq_all,def_rain &! input
    & ,maqi_all &! output
    & )
    
call get_parentrock( &
    & nsp_sld_all,chrsld_all,def_pr &! input
    & ,msldi_all &! output
    & )

! bulk soil concentration     
mblki = 0d0
incld_blk = .false.

! adding the case where input wt% exceeds 100% 
if ( sum(msldi_all) > 1d0) then 
    print *, 'parent rock comp. exceeds 100% so rescale'
    msldi_all = msldi_all/sum(msldi_all)  ! now the units are g/g
! endif 
! msldi_all = msldi_all/mwt_all*rho_grain*1d6 ! converting g/g to mol/sld m3
! msldi_all = (1d0 - poroi) * msldi_all       ! mol/sld m3 to mol/bulk m3 

! when input is less than 100wt% add bulk soil 
elseif ( sum(msldi_all) < 1d0 ) then 
    print *, 'parent rock comp. is less than 100% so add "bulk soil"'
    ! sum(msldi_all)  + mblki = 1d0
    incld_blk = .true.
    mblki = 1d0 - sum(msldi_all)
    if ( mblki < 0d0 ) mblki = 0d0
endif 

rho_grain_calc = rho_grain
msldi_allx = msldi_all/mwt_all*rho_grain_calc*1d6 !  converting g/g to mol/sld m3
mblkix = mblki/mwtblk*rho_grain_calc*1d6 !  converting g/g to mol/sld m3
! msldi_allx = msldi_allx/sum(msldi_allx*mv_all*1d-6)  !  try to make sure volume total must be 1 
msldi_allx = msldi_allx/( sum(msldi_allx*mv_all*1d-6) + mblkix*mvblk*1d-6 )  !  try to make sure volume total must be 1 (including bulk soil if any)
mblkix = mblkix/( sum(msldi_allx*mv_all*1d-6) + mblkix*mvblk*1d-6 )  !  try to make sure volume total must be 1 (including bulk soil if any)
if (msldunit=='blk') then 
    msldi_allx = msldi_allx*(1d0 - poroi)  !  try to make sure volume total must be 1 - poroi
    mblkix = mblkix*(1d0 - poroi)  !  try to make sure volume total must be 1 - poroi
endif 
! then the follwoing must be satisfied
! (1d0 - poroi)*rho_grain_calc = msldi_all*mwt_all*1d-6
! (1d0 - poroi) = msldi_all*mv_all*1d-6
rho_error = 1d4
rho_tol = 1d-6
! poroi_calc = 1d0 - sum(msldi_allx*mv_all*1d-6)
poroi_calc = 1d0 - ( sum( msldi_allx*mv_all*1d-6) + mblkix*mvblk*1d-6 ) ! corrected for bulk soil if any 
do while (rho_error > rho_tol) 
    rho_grain_calcx = rho_grain_calc
    
    ! rho_grain_calc = sum(msldi_allx(:)*mwt_all(:)*1d-6) ! /(1d0-poroi_calc)
    rho_grain_calc = sum(msldi_allx(:)*mwt_all(:)*1d-6)  + mblkix*mwtblk*1d-6  ! /(1d0-poroi_calc) | corrected for bulk soil 
    if (msldunit=='blk') rho_grain_calc = rho_grain_calc / (1d0-poroi_calc)
     
    msldi_allx = msldi_all/mwt_all*rho_grain_calc*1d6 !  converting g/g to mol/sld m3
    mblkix = mblki/mwtblk*rho_grain_calc*1d6 !  converting g/g to mol/sld m3
    ! msldi_allx = msldi_allx/sum(msldi_allx*mv_all*1d-6)  !  try to make sure volume total must be 1 
    msldi_allx = msldi_allx/( sum(msldi_allx*mv_all*1d-6) + mblkix*mvblk*1d-6 )  !  try to make sure volume total must be 1 | corrected for bulk soil 
    if (msldunit=='blk')  then 
        msldi_allx = (1d0 - poroi) * msldi_allx  !  converting mol/sld m3 to mol/bulk m3
        mblkix = (1d0 - poroi) * mblkix  !  converting mol/sld m3 to mol/bulk m3
    endif 
    
    ! poroi_calc = 1d0 - sum(msldi_allx*mv_all*1d-6)
    poroi_calc = 1d0 - ( sum(msldi_allx*mv_all*1d-6) + mblkix*mvblk*1d-6 ) ! corrected for bulk soil
    
    rho_error = abs ((rho_grain_calc - rho_grain_calcx)/rho_grain_calc) 
    
    print*,rho_error
    
enddo

if (msldunit=='sld') then 
    ! print *,1d0,sum(msldi_allx*mv_all*1d-6)
    ! print *,sum(msldi_allx*mwt_all*1d-6),rho_grain_calc
    print *,1d0,sum(msldi_allx*mv_all*1d-6) + mblkix*mvblk*1d-6
    print *,sum(msldi_allx*mwt_all*1d-6) + mblkix*mwtblk*1d-6 ,rho_grain_calc
elseif (msldunit=='blk') then 
    ! print *,1d0,sum(msldi_allx*mv_all*1d-6) /(1d0 - poroi)
    ! print *,sum(msldi_allx*mwt_all*1d-6)/(1d0 - poroi),rho_grain_calc
    print *,1d0,( sum(msldi_allx*mv_all*1d-6) + mblkix*mvblk*1d-6 )/(1d0 - poroi)
    print *,( sum(msldi_allx*mwt_all*1d-6) + mblkix*mwtblk*1d-6 )/(1d0 - poroi),rho_grain_calc
endif 
! print *,mblkix
! stop
msldi_all = msldi_allx
mblki = mblkix
rho_grain = rho_grain_calc

call get_atm( &
    & nsp_gas_all,chrgas_all &! input
    & ,mgasi_all &! output
    & )

! print*,maqi_all 
! print*,mgasi_all 
print*,msldi_all

! pause

! constant values are taken from the boundary values specified above 
do ispg = 1,nsp_gas_cnst
    mgasc(ispg,:) = mgasi_all(findloc(chrgas_all,chrgas_cnst(ispg),dim=1))
enddo 
do ispa = 1,nsp_aq_cnst
    maqc(ispa,:) = maqi_all(findloc(chraq_all,chraq_cnst(ispa),dim=1))
enddo 
do isps = 1,nsp_sld_cnst
    msldc(isps,:) = msldi_all(findloc(chrsld_all,chrsld_cnst(isps),dim=1))
enddo 

! threshould values 
mgasth_all = 1d-200
maqth_all = 1d-200
msldth_all = 1d-200


! passing initial and threshold values to explcit variables 
do isps = 1, nsp_sld    
    print *, chrsld(isps)
    if (any(chrsld_all == chrsld(isps))) then 
        msldi(isps) = msldi_all(findloc(chrsld_all,chrsld(isps),dim=1))
        msldth(isps) = msldth_all(findloc(chrsld_all,chrsld(isps),dim=1))
        print *,msldi(isps),msldi_all(findloc(chrsld_all,chrsld(isps),dim=1))
    endif 
enddo 
do ispa = 1, nsp_aq    
    if (any(chraq_all == chraq(ispa))) then 
        maqi(ispa) = maqi_all(findloc(chraq_all,chraq(ispa),dim=1))
        maqth(ispa) = maqth_all(findloc(chraq_all,chraq(ispa),dim=1))
    endif 
enddo 
do ispg = 1, nsp_gas    
    if (any(chrgas_all == chrgas(ispg))) then 
        mgasi(ispg) = mgasi_all(findloc(chrgas_all,chrgas(ispg),dim=1))
        mgasth(ispg) = mgasth_all(findloc(chrgas_all,chrgas(ispg),dim=1))
    endif 
enddo 

! print*,maqi 
! print*,mgasi
print*,msldi

! pause

! stoichiometry
! mineral dissolution(/precipitation)
staq_all = 0d0
stgas_all = 0d0
! Forsterite; Mg2SiO4
staq_all(findloc(chrsld_all,'fo',dim=1), findloc(chraq_all,'mg',dim=1)) = 2d0
staq_all(findloc(chrsld_all,'fo',dim=1), findloc(chraq_all,'si',dim=1)) = 1d0
! Albite; NaAlSi3O8
! staq_all(findloc(chrsld_all,'ab',dim=1), findloc(chraq_all,'na',dim=1)) = 1d0
! staq_all(findloc(chrsld_all,'ab',dim=1), findloc(chraq_all,'si',dim=1)) = 3d0
! staq_all(findloc(chrsld_all,'ab',dim=1), findloc(chraq_all,'al',dim=1)) = 1d0
! Analcime; NaAlSi2O6*H2O
staq_all(findloc(chrsld_all,'anl',dim=1), findloc(chraq_all,'na',dim=1)) = 1d0
staq_all(findloc(chrsld_all,'anl',dim=1), findloc(chraq_all,'si',dim=1)) = 2d0
staq_all(findloc(chrsld_all,'anl',dim=1), findloc(chraq_all,'al',dim=1)) = 1d0
! Nepheline; NaAlSiO4
staq_all(findloc(chrsld_all,'nph',dim=1), findloc(chraq_all,'na',dim=1)) = 1d0
staq_all(findloc(chrsld_all,'nph',dim=1), findloc(chraq_all,'si',dim=1)) = 1d0
staq_all(findloc(chrsld_all,'nph',dim=1), findloc(chraq_all,'al',dim=1)) = 1d0
! K-feldspar; KAlSi3O8
staq_all(findloc(chrsld_all,'kfs',dim=1), findloc(chraq_all,'k',dim=1)) = 1d0
staq_all(findloc(chrsld_all,'kfs',dim=1), findloc(chraq_all,'si',dim=1)) = 3d0
staq_all(findloc(chrsld_all,'kfs',dim=1), findloc(chraq_all,'al',dim=1)) = 1d0
! Anothite; CaAl2Si2O8
! staq_all(findloc(chrsld_all,'an',dim=1), findloc(chraq_all,'ca',dim=1)) = 1d0
! staq_all(findloc(chrsld_all,'an',dim=1), findloc(chraq_all,'si',dim=1)) = 2d0
! staq_all(findloc(chrsld_all,'an',dim=1), findloc(chraq_all,'al',dim=1)) = 2d0
! Albite; CaxNa(1-x)Al(1+x)Si(3-x)O8
staq_all(findloc(chrsld_all,'ab',dim=1), findloc(chraq_all,'ca',dim=1)) = fr_an_ab
staq_all(findloc(chrsld_all,'ab',dim=1), findloc(chraq_all,'na',dim=1)) = 1d0 - fr_an_ab
staq_all(findloc(chrsld_all,'ab',dim=1), findloc(chraq_all,'al',dim=1)) = 1d0 + fr_an_ab
staq_all(findloc(chrsld_all,'ab',dim=1), findloc(chraq_all,'si',dim=1)) = 3d0 - fr_an_ab
! Anothite; CaxNa(1-x)Al(1+x)Si(3-x)O8
staq_all(findloc(chrsld_all,'an',dim=1), findloc(chraq_all,'ca',dim=1)) = fr_an_an
staq_all(findloc(chrsld_all,'an',dim=1), findloc(chraq_all,'na',dim=1)) = 1d0 - fr_an_an
staq_all(findloc(chrsld_all,'an',dim=1), findloc(chraq_all,'al',dim=1)) = 1d0 + fr_an_an
staq_all(findloc(chrsld_all,'an',dim=1), findloc(chraq_all,'si',dim=1)) = 3d0 - fr_an_an
! Labradorite; CaxNa(1-x)Al(1+x)Si(3-x)O8
staq_all(findloc(chrsld_all,'la',dim=1), findloc(chraq_all,'ca',dim=1)) = fr_an_la
staq_all(findloc(chrsld_all,'la',dim=1), findloc(chraq_all,'na',dim=1)) = 1d0 - fr_an_la
staq_all(findloc(chrsld_all,'la',dim=1), findloc(chraq_all,'al',dim=1)) = 1d0 + fr_an_la
staq_all(findloc(chrsld_all,'la',dim=1), findloc(chraq_all,'si',dim=1)) = 3d0 - fr_an_la
! Andesine; CaxNa(1-x)Al(1+x)Si(3-x)O8
staq_all(findloc(chrsld_all,'and',dim=1), findloc(chraq_all,'ca',dim=1)) = fr_an_and
staq_all(findloc(chrsld_all,'and',dim=1), findloc(chraq_all,'na',dim=1)) = 1d0 - fr_an_and
staq_all(findloc(chrsld_all,'and',dim=1), findloc(chraq_all,'al',dim=1)) = 1d0 + fr_an_and
staq_all(findloc(chrsld_all,'and',dim=1), findloc(chraq_all,'si',dim=1)) = 3d0 - fr_an_and
! Oligoclase; CaxNa(1-x)Al(1+x)Si(3-x)O8
staq_all(findloc(chrsld_all,'olg',dim=1), findloc(chraq_all,'ca',dim=1)) = fr_an_olg
staq_all(findloc(chrsld_all,'olg',dim=1), findloc(chraq_all,'na',dim=1)) = 1d0 - fr_an_olg
staq_all(findloc(chrsld_all,'olg',dim=1), findloc(chraq_all,'al',dim=1)) = 1d0 + fr_an_olg
staq_all(findloc(chrsld_all,'olg',dim=1), findloc(chraq_all,'si',dim=1)) = 3d0 - fr_an_olg
! Bytownite; CaxNa(1-x)Al(1+x)Si(3-x)O8
staq_all(findloc(chrsld_all,'by',dim=1), findloc(chraq_all,'ca',dim=1)) = fr_an_by
staq_all(findloc(chrsld_all,'by',dim=1), findloc(chraq_all,'na',dim=1)) = 1d0 - fr_an_by
staq_all(findloc(chrsld_all,'by',dim=1), findloc(chraq_all,'al',dim=1)) = 1d0 + fr_an_by
staq_all(findloc(chrsld_all,'by',dim=1), findloc(chraq_all,'si',dim=1)) = 3d0 - fr_an_by
! Calcite; CaCO3
staq_all(findloc(chrsld_all,'cc',dim=1), findloc(chraq_all,'ca',dim=1)) = 1d0
stgas_all(findloc(chrsld_all,'cc',dim=1), findloc(chrgas_all,'pco2',dim=1)) = 1d0
! Kaolinite; Al2Si2O5(OH)4
staq_all(findloc(chrsld_all,'ka',dim=1), findloc(chraq_all,'si',dim=1)) = 2d0
staq_all(findloc(chrsld_all,'ka',dim=1), findloc(chraq_all,'al',dim=1)) = 2d0
! Gibbsite; Al(OH)3
staq_all(findloc(chrsld_all,'gb',dim=1), findloc(chraq_all,'al',dim=1)) = 1d0
! Pyrite; FeS2
staq_all(findloc(chrsld_all,'py',dim=1), findloc(chraq_all,'fe2',dim=1)) = 1d0
staq_all(findloc(chrsld_all,'py',dim=1), findloc(chraq_all,'so4',dim=1)) = 2d0
stgas_all(findloc(chrsld_all,'py',dim=1), findloc(chrgas_all,'po2',dim=1)) = -7d0/2d0
! Chrysotile; Mg3Si2O5(OH)4
staq_all(findloc(chrsld_all,'ct',dim=1), findloc(chraq_all,'si',dim=1)) = 2d0
staq_all(findloc(chrsld_all,'ct',dim=1), findloc(chraq_all,'mg',dim=1)) = 3d0
! Fayalite; Fe2SiO4
staq_all(findloc(chrsld_all,'fa',dim=1), findloc(chraq_all,'si',dim=1)) = 1d0
staq_all(findloc(chrsld_all,'fa',dim=1), findloc(chraq_all,'fe2',dim=1)) = 2d0
! Goethite; FeO(OH)
staq_all(findloc(chrsld_all,'gt',dim=1), findloc(chraq_all,'fe3',dim=1)) = 1d0
! Hematite; Fe2O3
staq_all(findloc(chrsld_all,'hm',dim=1), findloc(chraq_all,'fe3',dim=1)) = 2d0
! Ca-beidellite; Ca(1/6)Al(7/3)Si(11/3)O10(OH)2
staq_all(findloc(chrsld_all,'cabd',dim=1), findloc(chraq_all,'ca',dim=1)) = 1d0/6d0
staq_all(findloc(chrsld_all,'cabd',dim=1), findloc(chraq_all,'al',dim=1)) = 7d0/3d0
staq_all(findloc(chrsld_all,'cabd',dim=1), findloc(chraq_all,'si',dim=1)) = 11d0/3d0
! Mg-beidellite; Mg(1/6)Al(7/3)Si(11/3)O10(OH)2
staq_all(findloc(chrsld_all,'mgbd',dim=1), findloc(chraq_all,'mg',dim=1)) = 1d0/6d0
staq_all(findloc(chrsld_all,'mgbd',dim=1), findloc(chraq_all,'al',dim=1)) = 7d0/3d0
staq_all(findloc(chrsld_all,'mgbd',dim=1), findloc(chraq_all,'si',dim=1)) = 11d0/3d0
! K-beidellite; K(1/3)Al(7/3)Si(11/3)O10(OH)2
staq_all(findloc(chrsld_all,'kbd',dim=1), findloc(chraq_all,'k',dim=1)) = 1d0/3d0
staq_all(findloc(chrsld_all,'kbd',dim=1), findloc(chraq_all,'al',dim=1)) = 7d0/3d0
staq_all(findloc(chrsld_all,'kbd',dim=1), findloc(chraq_all,'si',dim=1)) = 11d0/3d0
! Na-beidellite; Na(1/3)Al(7/3)Si(11/3)O10(OH)2
staq_all(findloc(chrsld_all,'nabd',dim=1), findloc(chraq_all,'na',dim=1)) = 1d0/3d0
staq_all(findloc(chrsld_all,'nabd',dim=1), findloc(chraq_all,'al',dim=1)) = 7d0/3d0
staq_all(findloc(chrsld_all,'nabd',dim=1), findloc(chraq_all,'si',dim=1)) = 11d0/3d0
! Illite; K0.6Mg0.25Al2.3Si3.5O10(OH)2
staq_all(findloc(chrsld_all,'ill',dim=1), findloc(chraq_all,'k',dim=1)) = 0.6d0
staq_all(findloc(chrsld_all,'ill',dim=1), findloc(chraq_all,'mg',dim=1)) = 0.25d0
staq_all(findloc(chrsld_all,'ill',dim=1), findloc(chraq_all,'al',dim=1)) = 2.3d0
staq_all(findloc(chrsld_all,'ill',dim=1), findloc(chraq_all,'si',dim=1)) = 3.5d0
! Diopside (MgCaSi2O6)
staq_all(findloc(chrsld_all,'dp',dim=1), findloc(chraq_all,'ca',dim=1)) = 1d0
staq_all(findloc(chrsld_all,'dp',dim=1), findloc(chraq_all,'mg',dim=1)) = 1d0
staq_all(findloc(chrsld_all,'dp',dim=1), findloc(chraq_all,'si',dim=1)) = 2d0
! Hedenbergite (FeCaSi2O6)
staq_all(findloc(chrsld_all,'hb',dim=1), findloc(chraq_all,'ca',dim=1)) = 1d0
staq_all(findloc(chrsld_all,'hb',dim=1), findloc(chraq_all,'fe2',dim=1)) = 1d0
staq_all(findloc(chrsld_all,'hb',dim=1), findloc(chraq_all,'si',dim=1)) = 2d0
! Clinopyroxene (FexMg(1-x)CaSi2O6)
staq_all(findloc(chrsld_all,'cpx',dim=1), findloc(chraq_all,'ca',dim=1)) = 1d0
staq_all(findloc(chrsld_all,'cpx',dim=1), findloc(chraq_all,'fe2',dim=1)) = fr_hb_cpx
staq_all(findloc(chrsld_all,'cpx',dim=1), findloc(chraq_all,'mg',dim=1)) = 1d0 - fr_hb_cpx
staq_all(findloc(chrsld_all,'cpx',dim=1), findloc(chraq_all,'si',dim=1)) = 2d0
! Enstatite (MgSiO3)
staq_all(findloc(chrsld_all,'en',dim=1), findloc(chraq_all,'mg',dim=1)) = 1d0
staq_all(findloc(chrsld_all,'en',dim=1), findloc(chraq_all,'si',dim=1)) = 1d0
! Ferrosilite (FeSiO3)
staq_all(findloc(chrsld_all,'fer',dim=1), findloc(chraq_all,'fe2',dim=1)) = 1d0
staq_all(findloc(chrsld_all,'fer',dim=1), findloc(chraq_all,'si',dim=1)) = 1d0
! Orthopyroxene (FexMg(1-x)SiO3)
staq_all(findloc(chrsld_all,'opx',dim=1), findloc(chraq_all,'fe2',dim=1)) = fr_fer_opx
staq_all(findloc(chrsld_all,'opx',dim=1), findloc(chraq_all,'mg',dim=1)) = 1d0 - fr_fer_opx
staq_all(findloc(chrsld_all,'opx',dim=1), findloc(chraq_all,'si',dim=1)) = 1d0
! Augite (Fe(xy+x)Mg(y-xy+1-x)Ca(1-y)Si2O6); x=fr_fer_agt ; y=fr_opx_agt 
staq_all(findloc(chrsld_all,'agt',dim=1), findloc(chraq_all,'fe2',dim=1)) = fr_fer_agt* (1d0 + fr_opx_agt)
staq_all(findloc(chrsld_all,'agt',dim=1), findloc(chraq_all,'mg',dim=1)) = (1d0 - fr_fer_agt )*(fr_opx_agt + 1d0)
staq_all(findloc(chrsld_all,'agt',dim=1), findloc(chraq_all,'ca',dim=1)) = 1d0 - fr_opx_agt
staq_all(findloc(chrsld_all,'agt',dim=1), findloc(chraq_all,'si',dim=1)) = 2d0
! Tremolite (Ca2Mg5(Si8O22)(OH)2)
staq_all(findloc(chrsld_all,'tm',dim=1), findloc(chraq_all,'ca',dim=1)) = 2d0
staq_all(findloc(chrsld_all,'tm',dim=1), findloc(chraq_all,'mg',dim=1)) = 5d0
staq_all(findloc(chrsld_all,'tm',dim=1), findloc(chraq_all,'si',dim=1)) = 8d0
! Anthophyllite (Mg2Mg5(Si8O22)(OH)2)
staq_all(findloc(chrsld_all,'antp',dim=1), findloc(chraq_all,'mg',dim=1)) = 7d0
staq_all(findloc(chrsld_all,'antp',dim=1), findloc(chraq_all,'si',dim=1)) = 8d0
! Muscovite; KAl2(AlSi3O10)(OH)2
staq_all(findloc(chrsld_all,'mscv',dim=1), findloc(chraq_all,'k',dim=1)) = 1d0
staq_all(findloc(chrsld_all,'mscv',dim=1), findloc(chraq_all,'al',dim=1)) = 3d0
staq_all(findloc(chrsld_all,'mscv',dim=1), findloc(chraq_all,'si',dim=1)) = 3d0
! Phlogopite; KMg3(AlSi3O10)(OH)2
staq_all(findloc(chrsld_all,'plgp',dim=1), findloc(chraq_all,'k',dim=1)) = 1d0
staq_all(findloc(chrsld_all,'plgp',dim=1), findloc(chraq_all,'mg',dim=1)) = 3d0
staq_all(findloc(chrsld_all,'plgp',dim=1), findloc(chraq_all,'al',dim=1)) = 1d0
staq_all(findloc(chrsld_all,'plgp',dim=1), findloc(chraq_all,'si',dim=1)) = 3d0
! Amorphous silica; SiO2
staq_all(findloc(chrsld_all,'amsi',dim=1), findloc(chraq_all,'si',dim=1)) = 1d0
! Quartz; SiO2
staq_all(findloc(chrsld_all,'qtz',dim=1), findloc(chraq_all,'si',dim=1)) = 1d0
! Aragonite (CaCO3)
staq_all(findloc(chrsld_all,'arg',dim=1), findloc(chraq_all,'ca',dim=1)) = 1d0
stgas_all(findloc(chrsld_all,'arg',dim=1), findloc(chrgas_all,'pco2',dim=1)) = 1d0
! Dolomite (CaMg(CO3)2)
staq_all(findloc(chrsld_all,'dlm',dim=1), findloc(chraq_all,'ca',dim=1)) = 1d0
staq_all(findloc(chrsld_all,'dlm',dim=1), findloc(chraq_all,'mg',dim=1)) = 1d0
stgas_all(findloc(chrsld_all,'dlm',dim=1), findloc(chrgas_all,'pco2',dim=1)) = 2d0
! Gypsum; CaSO4*2H2O
staq_all(findloc(chrsld_all,'gps',dim=1), findloc(chraq_all,'ca',dim=1)) = 1d0
staq_all(findloc(chrsld_all,'gps',dim=1), findloc(chraq_all,'so4',dim=1)) = 1d0
! OMs; CH2O
stgas_all(findloc(chrsld_all,'g1',dim=1), findloc(chrgas_all,'pco2',dim=1)) = 1d0
stgas_all(findloc(chrsld_all,'g1',dim=1), findloc(chrgas_all,'po2',dim=1)) = -1d0
stgas_all(findloc(chrsld_all,'g1',dim=1), findloc(chrgas_all,'pnh3',dim=1)) = n2c_g1

stgas_all(findloc(chrsld_all,'g2',dim=1), findloc(chrgas_all,'pco2',dim=1)) = 1d0
stgas_all(findloc(chrsld_all,'g2',dim=1), findloc(chrgas_all,'po2',dim=1)) = -1d0
stgas_all(findloc(chrsld_all,'g2',dim=1), findloc(chrgas_all,'pnh3',dim=1)) = n2c_g2

stgas_all(findloc(chrsld_all,'g3',dim=1), findloc(chrgas_all,'pco2',dim=1)) = 1d0
stgas_all(findloc(chrsld_all,'g3',dim=1), findloc(chrgas_all,'po2',dim=1)) = -1d0
stgas_all(findloc(chrsld_all,'g3',dim=1), findloc(chrgas_all,'pnh3',dim=1)) = n2c_g3
! the above need to be modified to enable anoxic degradation 

staq = 0d0
stgas = 0d0

do isps = 1, nsp_sld
    if (any(chrsld_all == chrsld(isps))) then 
        do ispa = 1, nsp_aq 
            if (any(chraq_all == chraq(ispa))) then 
                staq(isps,ispa) = &
                    & staq_all(findloc(chrsld_all,chrsld(isps),dim=1), findloc(chraq_all,chraq(ispa),dim=1))
            endif 
        enddo 
        do ispg = 1, nsp_gas 
            if (any(chrgas_all == chrgas(ispg))) then 
                stgas(isps,ispg) = &
                    & stgas_all(findloc(chrsld_all,chrsld(isps),dim=1), findloc(chrgas_all,chrgas(ispg),dim=1))
            endif 
        enddo 
    endif 
enddo 

! external reactions
staq_ext_all = 0d0
stgas_ext_all = 0d0
stsld_ext_all = 0d0
! respiration 
stgas_ext_all(findloc(chrrxn_ext_all,'resp',dim=1), findloc(chrgas_all,'pco2',dim=1)) = 1d0
stgas_ext_all(findloc(chrrxn_ext_all,'resp',dim=1), findloc(chrgas_all,'po2',dim=1)) = -1d0
! fe2 oxidation 
staq_ext_all(findloc(chrrxn_ext_all,'fe2o2',dim=1), findloc(chraq_all,'fe2',dim=1)) = -1d0
staq_ext_all(findloc(chrrxn_ext_all,'fe2o2',dim=1), findloc(chraq_all,'fe3',dim=1)) = 1d0
stgas_ext_all(findloc(chrrxn_ext_all,'fe2o2',dim=1), findloc(chrgas_all,'po2',dim=1)) = -1d0/4d0
! SOC assimilation by microbes 
stsld_ext_all(findloc(chrrxn_ext_all,'omomb',dim=1), findloc(chrsld_all,'om',dim=1)) = -1d0
stsld_ext_all(findloc(chrrxn_ext_all,'omomb',dim=1), findloc(chrsld_all,'omb',dim=1)) = 0.31d0
stgas_ext_all(findloc(chrrxn_ext_all,'omomb',dim=1), findloc(chrgas_all,'pco2',dim=1)) = 0.69d0
stgas_ext_all(findloc(chrrxn_ext_all,'omomb',dim=1), findloc(chrgas_all,'po2',dim=1)) = -0.69d0
! turnover of microbes 
stsld_ext_all(findloc(chrrxn_ext_all,'ombto',dim=1), findloc(chrsld_all,'om',dim=1)) = 1d0
stsld_ext_all(findloc(chrrxn_ext_all,'ombto',dim=1), findloc(chrsld_all,'omb',dim=1)) = -1d0
! pyrite oxidation by fe3
stsld_ext_all(findloc(chrrxn_ext_all,'pyfe3',dim=1), findloc(chrsld_all,'py',dim=1)) = -1d0
staq_ext_all(findloc(chrrxn_ext_all,'pyfe3',dim=1), findloc(chraq_all,'fe3',dim=1)) = -14d0
staq_ext_all(findloc(chrrxn_ext_all,'pyfe3',dim=1), findloc(chraq_all,'fe2',dim=1)) = 15d0
staq_ext_all(findloc(chrrxn_ext_all,'pyfe3',dim=1), findloc(chraq_all,'so4',dim=1)) = 2d0
! ammonia oxidation by O2 (NH4+ + 2O2 -> NO3- + H2O + 2 H+) 
staq_ext_all(findloc(chrrxn_ext_all,'amo2o',dim=1), findloc(chraq_all,'no3',dim=1)) = 1d0
stgas_ext_all(findloc(chrrxn_ext_all,'amo2o',dim=1), findloc(chrgas_all,'pnh3',dim=1)) = -1d0
stgas_ext_all(findloc(chrrxn_ext_all,'amo2o',dim=1), findloc(chrgas_all,'po2',dim=1)) = -2d0
! overall denitrification (4 NO3-  +  5 CH2O  +  4 H+  ->  2 N2  +  5 CO2  +  7 H2O) 
staq_ext_all(findloc(chrrxn_ext_all,'g2n0',dim=1), findloc(chraq_all,'no3',dim=1)) = -4d0/5d0 ! values relative to CH2O 
stsld_ext_all(findloc(chrrxn_ext_all,'g2n0',dim=1), findloc(chrsld_all,'g2',dim=1)) = -1d0
stgas_ext_all(findloc(chrrxn_ext_all,'g2n0',dim=1), findloc(chrgas_all,'pco2',dim=1)) = 1d0
stgas_ext_all(findloc(chrrxn_ext_all,'g2n0',dim=1), findloc(chrgas_all,'pnh3',dim=1)) = n2c_g2
! stgas_ext_all(findloc(chrrxn_ext_all,'g2n0',dim=1), findloc(chrgas_all,'pn2',dim=1)) = 2d0/5d0 ! should be added after enabling pn2 
! first of 2 step denitrification (2 NO3-  +  2 CH2O  +  2 H+  ->  N2O  +  2 CO2  +  3 H2O) 
staq_ext_all(findloc(chrrxn_ext_all,'g2n21',dim=1), findloc(chraq_all,'no3',dim=1)) = -1d0  ! values relative to CH2O
stsld_ext_all(findloc(chrrxn_ext_all,'g2n21',dim=1), findloc(chrsld_all,'g2',dim=1)) = -1d0
stgas_ext_all(findloc(chrrxn_ext_all,'g2n21',dim=1), findloc(chrgas_all,'pco2',dim=1)) = 1d0
stgas_ext_all(findloc(chrrxn_ext_all,'g2n21',dim=1), findloc(chrgas_all,'pn2o',dim=1)) = 0.5d0
stgas_ext_all(findloc(chrrxn_ext_all,'g2n21',dim=1), findloc(chrgas_all,'pnh3',dim=1)) = n2c_g2
! 2nd of 2 step denitrification (2 N2O  +  CH2O  ->  2 N2  +  CO2  +  H2O) 
stsld_ext_all(findloc(chrrxn_ext_all,'g2n22',dim=1), findloc(chrsld_all,'g2',dim=1)) = -1d0 ! values relative to CH2O
stgas_ext_all(findloc(chrrxn_ext_all,'g2n22',dim=1), findloc(chrgas_all,'pco2',dim=1)) = 1d0
stgas_ext_all(findloc(chrrxn_ext_all,'g2n22',dim=1), findloc(chrgas_all,'pn2o',dim=1)) = -2d0
stgas_ext_all(findloc(chrrxn_ext_all,'g2n22',dim=1), findloc(chrgas_all,'pnh3',dim=1)) = n2c_g2
! stgas_ext_all(findloc(chrrxn_ext_all,'g2n22',dim=1), findloc(chrgas_all,'pn2',dim=1)) = 2d0 ! should be added after enabling pn2 

! define 1 when a reaction is sensitive to a speces 
stgas_dext_all = 0d0
staq_dext_all = 0d0
stsld_dext_all = 0d0
! respiration 
stgas_dext_all(findloc(chrrxn_ext_all,'resp',dim=1), findloc(chrgas_all,'po2',dim=1)) = 1d0
! fe2 oxidation 
stgas_dext_all(findloc(chrrxn_ext_all,'fe2o2',dim=1), findloc(chrgas_all,'po2',dim=1)) = 1d0
stgas_dext_all(findloc(chrrxn_ext_all,'fe2o2',dim=1), findloc(chrgas_all,'pco2',dim=1)) = 1d0
staq_dext_all(findloc(chrrxn_ext_all,'fe2o2',dim=1), findloc(chraq_all,'fe2',dim=1)) = 1d0
! SOC assimilation by microbes 
stsld_dext_all(findloc(chrrxn_ext_all,'omomb',dim=1), findloc(chrsld_all,'om',dim=1)) = 1d0
stsld_dext_all(findloc(chrrxn_ext_all,'omomb',dim=1), findloc(chrsld_all,'omb',dim=1)) = 1d0
! turnover of microbes 
stsld_dext_all(findloc(chrrxn_ext_all,'ombto',dim=1), findloc(chrsld_all,'omb',dim=1)) = 1d0
! pyrite oxidation by fe3
stsld_dext_all(findloc(chrrxn_ext_all,'pyfe3',dim=1), findloc(chrsld_all,'py',dim=1)) = 1d0
staq_dext_all(findloc(chrrxn_ext_all,'pyfe3',dim=1), findloc(chraq_all,'fe2',dim=1)) = 1d0
staq_dext_all(findloc(chrrxn_ext_all,'pyfe3',dim=1), findloc(chraq_all,'fe3',dim=1)) = 1d0
! ammonia oxidation by O2 (NH4+ + 2O2 -> NO3- + H2O + 2 H+) 
stgas_dext_all(findloc(chrrxn_ext_all,'amo2o',dim=1), findloc(chrgas_all,'po2',dim=1)) = 1d0
stgas_dext_all(findloc(chrrxn_ext_all,'amo2o',dim=1), findloc(chrgas_all,'pnh3',dim=1)) = 1d0
! overall denitrification (4 NO3-  +  5 CH2O  +  4 H+  ->  2 N2  +  5 CO2  +  7 H2O) 
staq_dext_all(findloc(chrrxn_ext_all,'g2n0',dim=1), findloc(chraq_all,'no3',dim=1)) = 1d0
stgas_dext_all(findloc(chrrxn_ext_all,'g2n0',dim=1), findloc(chrgas_all,'po2',dim=1)) = 1d0
stsld_dext_all(findloc(chrrxn_ext_all,'g2n0',dim=1), findloc(chrsld_all,'g2',dim=1)) = 1d0
! first of 2 step denitrification (2 NO3-  +  2 CH2O  +  2 H+  ->  N2O  +  2 CO2  +  3 H2O) 
staq_dext_all(findloc(chrrxn_ext_all,'g2n21',dim=1), findloc(chraq_all,'no3',dim=1)) = 1d0
stgas_dext_all(findloc(chrrxn_ext_all,'g2n21',dim=1), findloc(chrgas_all,'po2',dim=1)) = 1d0
stsld_dext_all(findloc(chrrxn_ext_all,'g2n21',dim=1), findloc(chrsld_all,'g2',dim=1)) = 1d0
! 2nd of 2 step denitrification (2 N2O  +  CH2O  ->  2 N2  +  CO2  +  H2O) 
staq_dext_all(findloc(chrrxn_ext_all,'g2n22',dim=1), findloc(chraq_all,'no3',dim=1)) = 1d0
! stgas_dext_all(findloc(chrrxn_ext_all,'g2n22',dim=1), findloc(chrgas_all,'po2',dim=1)) = 1d0
stgas_dext_all(findloc(chrrxn_ext_all,'g2n22',dim=1), findloc(chrgas_all,'pn2o',dim=1)) = 1d0
stsld_dext_all(findloc(chrrxn_ext_all,'g2n22',dim=1), findloc(chrsld_all,'g2',dim=1)) = 1d0

staq_ext = 0d0
stgas_ext = 0d0
stsld_ext = 0d0

do irxn = 1, nrxn_ext
    if (any(chrrxn_ext_all == chrrxn_ext(irxn))) then 
        do ispa = 1, nsp_aq 
            if (any(chraq_all == chraq(ispa))) then 
                staq_ext(irxn,ispa) = &
                    & staq_ext_all(findloc(chrrxn_ext_all,chrrxn_ext(irxn),dim=1) &
                    &   ,findloc(chraq_all,chraq(ispa),dim=1))
                staq_dext(irxn,ispa) = &
                    & staq_dext_all(findloc(chrrxn_ext_all,chrrxn_ext(irxn),dim=1) &
                    &   ,findloc(chraq_all,chraq(ispa),dim=1))
            endif 
        enddo 
        do ispg = 1, nsp_gas 
            if (any(chrgas_all == chrgas(ispg))) then 
                stgas_ext(irxn,ispg) = &
                    & stgas_ext_all(findloc(chrrxn_ext_all,chrrxn_ext(irxn),dim=1) &
                    &   ,findloc(chrgas_all,chrgas(ispg),dim=1))
                stgas_dext(irxn,ispg) = &
                    & stgas_dext_all(findloc(chrrxn_ext_all,chrrxn_ext(irxn),dim=1) &
                    &   ,findloc(chrgas_all,chrgas(ispg),dim=1))
            endif 
        enddo 
        do isps = 1, nsp_sld 
            if (any(chrsld_all == chrsld(isps))) then 
                stsld_ext(irxn,isps) = &
                    & stsld_ext_all(findloc(chrrxn_ext_all,chrrxn_ext(irxn),dim=1) &
                    &   ,findloc(chrsld_all,chrsld(isps),dim=1))
                stsld_dext(irxn,isps) = &
                    & stsld_dext_all(findloc(chrrxn_ext_all,chrrxn_ext(irxn),dim=1) &
                    &   ,findloc(chrsld_all,chrsld(isps),dim=1))
            endif 
        enddo 
    endif 
enddo 


def_dust = 0d0
    
call get_dust( &
    & nsp_sld_all,chrsld_all,def_dust &! input
    & ,rfrc_sld_all &! output
    & )

rfrc_sld_all = rfrc_sld_all/mwt_all
! rfrc_sld_all = rfrc_sld_all/sum(rfrc_sld_all)




! rfrc_sld_plant_all(findloc(chrsld_all,'om',dim=1)) = 1d0

! rfrc_sld_plant_all(findloc(chrsld_all,'g1',dim=1)) = 0.1d0
! rfrc_sld_plant_all(findloc(chrsld_all,'g2',dim=1)) = 0.8d0
! rfrc_sld_plant_all(findloc(chrsld_all,'g3',dim=1)) = 0.1d0

def_OM_frc = 0d0

call get_OM_rain( &
    & nsp_sld_all,chrsld_all,def_OM_frc &! input
    & ,rfrc_sld_plant_all &! output
    & )

! rfrc_sld_plant_all = rfrc_sld_plant_all/mwt_all
! rfrc_sld_plant_all = rfrc_sld_plant_all/sum(rfrc_sld_plant_all)



do isps = 1, nsp_sld 
    rfrc_sld(isps) = rfrc_sld_all(findloc(chrsld_all,chrsld(isps),dim=1))
    rfrc_sld_plant(isps) = rfrc_sld_plant_all(findloc(chrsld_all,chrsld(isps),dim=1))
enddo


call get_switches( &
    & iwtype,imixtype,poroiter_in,display,display_lim_in,read_data,incld_rough &
    & ,al_inhibit,timestep_fixed,method_precalc,regular_grid,sld_enforce &! inout
    & ,poroevol,surfevol1,surfevol2,do_psd &!
    & )

no_biot = .false.
biot_turbo2 = .false.
biot_fick = .false.
biot_labs = .false.
biot_till = .false.

select case(imixtype)
    case(imixtype_nobio)
        no_biot = .true.
    case(imixtype_fick)
        biot_fick = .true.
    case(imixtype_turbo2)
        biot_turbo2 = .true.
    case(imixtype_till)
        biot_till = .true.
    case(imixtype_labs)
        biot_labs = .true.
    case default 
        print *, '***| chosen number is not available for mixing styles (choose between 0 to 4)'
        print *, '***| thus choose default |---- > no mixing'
        no_biot = .true.
endselect 

print *, 'no_biot,biot_fick,biot_turbo2,biot_till,biot_labs'
print *, no_biot,biot_fick,biot_turbo2,biot_till,biot_labs

select case(iwtype)
    case(iwtype_cnst)
        print *, 'const w',iwtype
    case(iwtype_flex)
        print *, 'w flex (cnst porosity profile)',iwtype
    case(iwtype_pwcnst)
        print *, 'w x porosity = cnst',iwtype
    case(iwtype_spwcnst)
        print *, 'w x (1 - porosity) = cnst',iwtype
    case default 
        print *, '***| chosen number is not available for advection styles (choose between 0 to 3)'
        print *, '***| thus choose default |---- > cnst w'
        iwtype = iwtype_cnst
endselect 

if (poroiter_in) then 
    print *, 'porosity iteration is ON'
else 
    print *, 'porosity iteration is OFF'
endif 

if (display_lim_in) display_lim = .true.

if (sld_enforce) nsp3 = nsp_aq + nsp_gas ! excluding solid phases

do while (rectime(nrec)>ttot) 
    rectime = rectime/10d0
enddo 
do while (rectime(nrec)<ttot) 
    rectime = rectime*10d0
enddo 

! write(chrq(1),'(i0)') int(qin/(10d0**(floor(log10(qin)))))
! write(chrq(2),'(i0)') floor(log10(qin))
! chrq(3) = trim(adjustl(chrq(1)))//'E'//trim(adjustl(chrq(2)))
write(chrq(3),'(E10.2)') qin
write(chrz(3),'(i0)') nint(zsat)
write(chrrain,'(E10.2)') rainpowder


! write(workdir,*) '../pyweath_output/'     
write(workdir,*) './'    
write(flxdir,*) './flx'    
write(profdir,*) './prof'     

! if (cplprec) then 
    ! write(base,*) 'test_cplp_test'
! else 
    ! write(base,*) 'test_cpl'
! endif 

base = trim(adjustl(sim_name))

if (al_inhibit) base = trim(adjustl(base))//'_alx'

base = trim(adjustl(base))//'_rain-'//trim(adjustl(chrrain))    
 
if (poroevol) then      
    base = trim(adjustl(base))//'_pevol'
endif 
if (surfevol1)then 
    base = trim(adjustl(base))//'_sevol1'
elseif (surfevol2) then 
    base = trim(adjustl(base))//'_sevol2'
#if defined(surfssa)
    base = trim(adjustl(base))//'_ssa'
#endif 
endif 

if (.not. regular_grid) then 
    base = trim(adjustl(base))//'_irr'
endif 

if (dust_wave)then 
    write(chrrain,'(E10.2)') wave_tau
    base = trim(adjustl(base))//'_rwave-'//trim(adjustl(chrrain))
endif 

if (incld_rough)then 
    write(chrrain,'(E10.2)') p80
    base = trim(adjustl(base))//'_p80r-'//trim(adjustl(chrrain))
else
    write(chrrain,'(E10.2)') p80
    base = trim(adjustl(base))//'_p80-'//trim(adjustl(chrrain))
endif 

write(runname,*) trim(adjustl(base))//'_q-'//trim(adjustl(chrq(3)))//'_zsat-'  &
    & //trim(adjustl(chrz(3)))
    
! directly name runname from input 
! write(runname,*) trim(adjustl(sim_name))
write(runname,*) 'output'

#ifdef full_flux_report
do isps = 1, nsp_sld 
    do iz = 1, nz
        isldflx(isps,iz) = idust + (isps-1)*nz + iz
        ! print *,isldflx(isps,iz)
    enddo 
enddo     
do ispa = 1, nsp_aq 
    do iz=1,nz
        iaqflx(ispa,iz) = idust + nsp_sld*nz  + (ispa - 1)*nz + iz
        ! print *,iaqflx(ispa,iz)
    enddo
enddo 

do ispg = 1, nsp_gas
    do iz= 1,nz
        igasflx(ispg,iz) = idust + nsp_sld*nz + nsp_aq*nz + (ispg-1)*nz + iz
        ! print*,igasflx(ispg,iz)
    enddo 
enddo 

do ico2 = 1, 6
    do iz = 1, nz
        ico2flx(ico2,iz) = idust + nsp_sld*nz + nsp_aq*nz + nsp_gas*nz + (ico2 - 1)*nz + iz
        ! print*,ico2flx(ico2,iz)
    enddo 
enddo 
! pause
#else 
do isps = 1, nsp_sld 
    isldflx(isps) = idust + isps
enddo 
    
do ispa = 1, nsp_aq 
    iaqflx(ispa) = idust + nsp_sld  + ispa
enddo 

do ispg = 1, nsp_gas
    igasflx(ispg) = idust + nsp_sld + nsp_aq + ispg
enddo 

do ico2 = 1, 6
    ico2flx(ico2) = idust + nsp_sld + nsp_aq + nsp_gas + ico2
enddo 
#endif 

! print*,workdir
! print*,runname
! pause

! call system ('mkdir -p '//trim(adjustl(workdir))//trim(adjustl(runname)))
call system ('mkdir -p '//trim(adjustl(flxdir)))
call system ('mkdir -p '//trim(adjustl(profdir)))

! call system ('cp gases.in solutes.in slds.in extrxns.in '//trim(adjustl(workdir))//trim(adjustl(runname)))

#ifdef full_flux_report

write(chrfmt,'(i0)') nflx+2

chrfmt = '('//trim(adjustl(chrfmt))//'(1x,a))'

do isps = 1,nsp_sld
    do iz = 1,nz
        write(chriz,'(i3.3)') iz
        open(isldflx(isps,iz), file=trim(adjustl(flxdir))//'/' &
            & //'flx_sld-'//trim(adjustl(chrsld(isps)))//'-'//trim(adjustl(chriz))//'.txt' &
            & , status='replace')
        write(isldflx(isps,iz),trim(adjustl(chrfmt))) 'time','z',(chrflx(iflx),iflx=1,nflx)
        close(isldflx(isps,iz))
    enddo 
enddo 

do ispa = 1,nsp_aq
    do iz= 1,nz
        write(chriz,'(i3.3)') iz
        open(iaqflx(ispa,iz), file=trim(adjustl(flxdir))//'/' &
            & //'flx_aq-'//trim(adjustl(chraq(ispa)))//'-'//trim(adjustl(chriz))//'.txt' &
            & , status='replace')
        write(iaqflx(ispa,iz),trim(adjustl(chrfmt))) 'time','z',(chrflx(iflx),iflx=1,nflx)
        close(iaqflx(ispa,iz))
    enddo 
enddo 

do ispg = 1,nsp_gas
    do iz=1,nz
        write(chriz,'(i3.3)') iz
        open(igasflx(ispg,iz), file=trim(adjustl(flxdir))//'/' &
            & //'flx_gas-'//trim(adjustl(chrgas(ispg)))//'-'//trim(adjustl(chriz))//'.txt' &
            & , status='replace')
        write(igasflx(ispg,iz),trim(adjustl(chrfmt))) 'time','z',(chrflx(iflx),iflx=1,nflx)
        close(igasflx(ispg,iz))
    enddo 
enddo 

do ico2 = 1,6
    do iz= 1,nz
        write(chriz,'(i3.3)') iz
        open(ico2flx(ico2,iz), file=trim(adjustl(flxdir))//'/' &
            & //'flx_co2sp-'//trim(adjustl(chrco2sp(ico2)))//'-'//trim(adjustl(chriz))//'.txt' &
            & , status='replace')
        write(ico2flx(ico2,iz),trim(adjustl(chrfmt))) 'time','z',(chrflx(iflx),iflx=1,nflx)
        close(ico2flx(ico2,iz))
    enddo 
enddo 

#else 

write(chrfmt,'(i0)') nflx+1

chrfmt = '('//trim(adjustl(chrfmt))//'(1x,a))'

do isps = 1,nsp_sld
    open(isldflx(isps), file=trim(adjustl(flxdir))//'/' &
        & //'flx_sld-'//trim(adjustl(chrsld(isps)))//'.txt', status='replace')
    write(isldflx(isps),trim(adjustl(chrfmt))) 'time',(chrflx(iflx),iflx=1,nflx)
    close(isldflx(isps))
enddo 

do ispa = 1,nsp_aq
    open(iaqflx(ispa), file=trim(adjustl(flxdir))//'/' &
        & //'flx_aq-'//trim(adjustl(chraq(ispa)))//'.txt', status='replace')
    write(iaqflx(ispa),trim(adjustl(chrfmt))) 'time',(chrflx(iflx),iflx=1,nflx)
    close(iaqflx(ispa))
enddo 

do ispg = 1,nsp_gas
    open(igasflx(ispg), file=trim(adjustl(flxdir))//'/' &
        & //'flx_gas-'//trim(adjustl(chrgas(ispg)))//'.txt', status='replace')
    write(igasflx(ispg),trim(adjustl(chrfmt))) 'time',(chrflx(iflx),iflx=1,nflx)
    close(igasflx(ispg))
enddo 

do ico2 = 1,6
    open(ico2flx(ico2), file=trim(adjustl(flxdir))//'/' &
        & //'flx_co2sp-'//trim(adjustl(chrco2sp(ico2)))//'.txt', status='replace')
    write(ico2flx(ico2),trim(adjustl(chrfmt))) 'time',(chrflx(iflx),iflx=1,nflx)
    close(ico2flx(ico2))
enddo 

#endif 

open(idust, file=trim(adjustl(flxdir))//'/'//'dust.txt', &
    & status='replace')
write(idust,*) ' time ', ' dust(relative_to_average) '
close(idust)

climate(:) = .true.
climate(:) = .false.

open(idust, file=trim(adjustl(flxdir))//'/'//'climate.txt', &
    & status='replace')
write(idust,*) ' time ', ' T(oC) ', ' q(m/yr) ', ' Wet(-) '
close(idust)

clim_file = (/'T_temp.in  ','q_temp.in  ','Wet_temp.in'/)

do iclim = 1,3
    if (climate(iclim)) then 
        call get_clim_num( &
            & clim_file(iclim) &! in 
            & ,nclim(iclim) &! output
            & ) 
        select case (iclim) 
            case(1)
                if ( allocated(clim_T) ) deallocate(clim_T)
                allocate(clim_T(2,nclim(iclim)))    
                open(idust,file=trim(adjustl(workdir))//'/'//trim(adjustl(clim_file(iclim))),  &
                    & status ='old',action='read')
                read (idust,'()')
                clim_T = 0d0
                do ict = 1, nclim(iclim)
                    read (idust,*) clim_T(1,ict),clim_T(2,ict)
                enddo 
                close(idust)
                print *
                do ict = 1, nclim(iclim)
                    print *, clim_T(:,ict)
                enddo 
                dct(iclim) = clim_T(1,2) - clim_T(1,1)
                ctau(iclim) = clim_T(1,nclim(iclim)) + dct(iclim)
            case(2)
                if ( allocated(clim_q) ) deallocate(clim_q)
                allocate(clim_q(2,nclim(iclim)))
                open(idust,file=trim(adjustl(workdir))//'/'//trim(adjustl(clim_file(iclim))),  &
                    & status ='old',action='read')
                read (idust,'()')
                clim_q = 0d0
                do ict = 1, nclim(iclim)
                    read (idust,*) clim_q(1,ict),clim_q(2,ict)
                enddo 
                close(idust)
                ! converting mm/month to m/yr 
                clim_q(2,:) = clim_q(2,:)*12d0/1d3
                print *
                do ict = 1, nclim(iclim)
                    print *, clim_q(:,ict)
                enddo 
                dct(iclim) = clim_q(1,2) - clim_q(1,1)
                ctau(iclim) = clim_q(1,nclim(iclim)) + dct(iclim)
            case(3)
                if ( allocated(clim_sat) ) deallocate(clim_sat)
                allocate(clim_sat(2,nclim(iclim)))
                open(idust,file=trim(adjustl(workdir))//'/'//trim(adjustl(clim_file(iclim))),  &
                    & status ='old',action='read')
                read (idust,'()')
                clim_sat = 0d0
                do ict = 1, nclim(iclim)
                    read (idust,*) clim_sat(1,ict),clim_sat(2,ict)
                enddo 
                close(idust)
                ! converting mm/m to m/m 
                clim_sat(2,:) = clim_sat(2,:)*1d0/1d3
                print *
                do ict = 1, nclim(iclim)
                    print *, clim_sat(:,ict)
                enddo 
                dct(iclim) = clim_sat(1,2) - clim_sat(1,1)
                ctau(iclim) = clim_sat(1,nclim(iclim)) + dct(iclim)
            case default
                print*, 'error in obtaining climate'
                stop
        endselect 
    endif 
enddo 

! stop

!!!  MAKING GRID !!!!!!!!!!!!!!!!! 
beta = 1.00000000005d0  ! a parameter to make a grid; closer to 1, grid space is more concentrated around the sediment-water interface (SWI)
beta = 1.00005d0  ! a parameter to make a grid; closer to 1, grid space is more concentrated around the sediment-water interface (SWI)
call makegrid(beta,nz,ztot,dz,z,regular_grid)


sat = min(1.0d0,(1d0-satup)*z/zsat + satup)
#ifdef satconvex 
sat = min(1.0d0, satup+(1d0-satup)*(z/zsat)**2d0)
#endif 
#ifdef satconcave 
sat = min(1.0d0, 1d0-(1d0-satup)*(1d0-z/zsat)**2d0)
do iz=1,nz
    if (z(iz)>=zsat) sat(iz)=1d0
enddo 
#endif 

rough = 1d0
if (incld_rough) then 
    ! rough = 10d0**(3.3d0)*p80**0.33d0 ! from Navarre-Sitchler and Brantley (2007)
    rough = rough_c0*p80**rough_c1 ! from Navarre-Sitchler and Brantley (2007)
endif 

! ssa_cmn = -4.4528d0*log10(p80*1d6) + 11.578d0 ! m2/g

hrii = 1d0/p80
hri = hrii

hr = hri*rough
v = qin/poroi/sat
poro = poroi
torg = poro**(3.4d0-2.0d0)*(1.0d0-sat)**(3.4d0-1.0d0)
tora = poro**(3.4d0-2.0d0)*(sat)**(3.4d0-1.0d0)

w_btm = w0
w = w_btm
! if (noncnstw) then 
    ! w(:) = w0/(1d0- poro(:)) ! from w*(1- poro) = w0*(1 - poroi) --- isovolumetric weathering?
    ! w_btm = w0/(1d0- poroi) ! from w*(1- poro) = w0*(1 - poroi) --- isovolumetric weathering?
! endif 


! ------------ determine calculation scheme for advection (from IMP code)
call calcupwindscheme(  &
    up,dwn,cnr,adf & ! output 
    ,w,nz   & ! input &
    )

! attempting to do psd 
if (do_psd) then 
    do ips = 1, nps
        ps(ips) = log10(ps_min) + (ips - 1d0)*(log10(ps_max) - log10(ps_min))/(nps - 1d0)
    enddo 
    dps(:) = ps(2) - ps(1)
    print *,ps
    print *,dps

    psu_pr = log10(p80)
    pssigma_pr = 1d0
    pssigma_pr = ps_sigma_std

    ! calculate parent rock particle size distribution 
    psd_pr = 1d0/pssigma_pr/sqrt(2d0*pi)*exp( -0.5d0*( (ps - psu_pr)/pssigma_pr )**2d0 )

    ! to ensure sum is 1
    ! print *, sum(psd_pr*dps)
    psd_pr = psd_pr/sum(psd_pr*dps)  
    ! print *, sum(psd_pr*dps)
    ! stop

    ! balance for volumes
    ! sum(msldi*mv*1d-6) (m3/m3) must be equal to sum( 4/3(pi)r3 * psd_pr * dps) 
    ! where psd is number / bulk m3 / log r 
    ! (if msld is defined as mol/sld m3 then msldi needs to be multiplied by (1 - poro)
    psd_pr = psd_pr*( sum(msldi*mv*1d-6) + mblki*mvblk*1d-6 )  &
        & /sum(4d0/3d0*pi*(10d0**ps(:))**3d0*psd_pr(:)*dps(:))
    
    if ( msldunit == 'sld') then 
        psd_pr = psd_pr*(1d0-poroi)
    
        if ( abs( ( ( sum(msldi*mv*1d-6) + mblki*mvblk*1d-6 ) &
            & * (1d0-poroi) & 
            & -sum(4d0/3d0*pi*(10d0**ps(:))**3d0*psd_pr(:)*dps(:))) &
            & / ( ( sum(msldi*mv*1d-6) + mblki*mvblk*1d-6 ) &
            & * (1d0-poroi) & 
            & )  ) > tol) then 
            print *,( sum(msldi*mv*1d-6) + mblki*mvblk*1d-6 ) &
                & * (1d0-poroi) & 
                & ,sum(4d0/3d0*pi*(10d0**ps(:))**3d0*psd_pr(:)*dps(:))
            stop
        endif 
    elseif ( msldunit == 'blk') then 
    
        if ( abs( ( ( sum(msldi*mv*1d-6) + mblki*mvblk*1d-6 ) &
            & -sum(4d0/3d0*pi*(10d0**ps(:))**3d0*psd_pr(:)*dps(:))) &
            & / ( ( sum(msldi*mv*1d-6) + mblki*mvblk*1d-6 ) &
            & )  ) > tol) then 
            print *,( sum(msldi*mv*1d-6) + mblki*mvblk*1d-6 ) &
                & ,sum(4d0/3d0*pi*(10d0**ps(:))**3d0*psd_pr(:)*dps(:))
            stop
        endif 
    endif 

    open(ipsd,file = trim(adjustl(profdir))//'/'//'psd_pr.txt',status = 'replace')
    write(ipsd,*) ' depth\log10(radius) ', (ps(ips),ips=1,nps), 'time'
    write(ipsd,*) ztot,(psd_pr(ips),ips=1,nps), 0d0
    close(ipsd)
    

    ! initially particle is distributed as in parent rock 
    do iz = 1, nz
        psd(:,iz) = psd_pr(:) 
    enddo 

    ! dM = M * [psd*dps*S(r)] * k *dt 
    ! so hr = sum (psd(:)*dps(:)*S(:) ) where S in units m2/m3 and simplest way 1/r 
    ! in this case hr = sum(  psd(:)*dps(:)*1d0/(10d0**(-ps(:))) )
    if (.not.incld_rough) then 
        do iz=1,nz
            hr(iz) = sum( 4d0*pi*(10d0**ps(:))**2d0*psd(:,iz)*dps(:))
        enddo 
    else 
        do iz=1,nz
            hr(iz) = sum( 4d0*pi*(10d0**ps(:))**2d0 *rough_c0*(10d0**ps(:))**rough_c1*psd(:,iz)*dps(:))
        enddo 
    endif 
    ssa = hr
    ! hr = ssa *(1-poro)/poro ! converting m2/sld-m3 to m2/pore-m3
    ! hr = ssa 
    hr = ssa/poro ! so that poro * hr * mv * msld becomes porosity independent
else 
    psd = 0d0
endif 

! #ifdef surfssa
! hri = ssa_cmn*1d6/poro
! mvab_save = mvab
! mvan_save = mvan
! mvcc_save = mvcc
! mvfo_save = mvfo
! mvka_save = mvka
! mvab = mwtab 
! mvan = mwtan 
! mvcc = mwtcc 
! mvfo = mwtfo 
! mvka = mwtka 
! #endif 

dt = maxdt

dt = 1d-20 ! for basalt exp?

do ispa = 1, nsp_aq
    maq(ispa,:)=maqi(ispa)
enddo 
do ispg = 1, nsp_gas
    mgas(ispg,:)=mgasi(ispg)
enddo 
do isps = 1, nsp_sld
    msld(isps,:) = msldi(isps)
enddo 

mblk = mblki

! initial solid conc. modified 
! do iz = 1, nz
    ! msld(:,iz) = msld(:,iz)*exp( real(iz - nz) )
    ! poro(iz) = 1d0 - sum(msld(:,iz)*mv(:)*1d-6)
! enddo 

omega = 0d0

pro = 1d-5

if (allocated(kin_sld_spc)) deallocate(kin_sld_spc)
if (allocated(chrsld_kinspc)) deallocate(chrsld_kinspc)
nsld_kinspc = nsld_kinspc_in
allocate(chrsld_kinspc(nsld_kinspc),kin_sld_spc(nsld_kinspc))
chrsld_kinspc = chrsld_kinspc_in
kin_sld_spc = kin_sld_spc_in
    
call coefs_v2( &
    & nz,rg,rg2,tc,sec2yr,tempk_0,pro,poro,hr &! input
    & ,nsp_aq_all,nsp_gas_all,nsp_sld_all,nrxn_ext_all &! input
    & ,chraq_all,chrgas_all,chrsld_all,chrrxn_ext_all &! input
    & ,nsp_gas,nsp_gas_cnst,chrgas,chrgas_cnst,mgas,mgasc,mgasth_all,mv_all,staq_all &!input
    & ,ucv,kw,daq_all,dgasa_all,dgasg_all,keqgas_h,keqaq_h,keqaq_c,keqaq_s,keqaq_no3,keqaq_nh3 &! output
    & ,ksld_all,keqsld_all,krxn1_ext_all,krxn2_ext_all &! output
    & ) 

print_cb = .false. 
print_loc = './ph.txt'

#ifdef phv7_2
call calc_pH_v7_2( &
    & nz,kw,nsp_aq,nsp_gas,nsp_aq_all,nsp_gas_all,nsp_aq_cnst,nsp_gas_cnst &! input 
    & ,chraq,chraq_cnst,chraq_all,chrgas,chrgas_cnst,chrgas_all &!input
    & ,maq,maqc,mgas,mgasc,keqgas_h,keqaq_h,keqaq_c,keqaq_s,maqth_all,keqaq_no3,keqaq_nh3 &! input
    & ,print_cb,print_loc,z &! input 
    & ,pro,ph_error,so4f,ph_iter &! output
    & ) 
#else
call calc_pH_v7_3( &
    & nz,kw,nsp_aq,nsp_gas,nsp_aq_all,nsp_gas_all,nsp_aq_cnst,nsp_gas_cnst &! input 
    & ,chraq,chraq_cnst,chraq_all,chrgas,chrgas_cnst,chrgas_all &!input
    & ,maq,maqc,mgas,mgasc,keqgas_h,keqaq_h,keqaq_c,keqaq_s,maqth_all,keqaq_no3,keqaq_nh3 &! input
    & ,print_cb,print_loc,z &! input 
    & ,dprodmaq_all,dprodmgas_all,dso4fdmaq_all,dso4fdmgas_all &! output
    & ,pro,ph_error,so4f,ph_iter &! output
    & ) 

#endif 

so4fprev = so4f
proi = pro(1)
print*,proi
! pause

poroprev = poro

!  --------- read -----
if (read_data) then 
    ! runname_save = 'test_cpl_rain-0.40E+04_pevol_sevol1_q-0.10E-01_zsat-5' ! specifiy the file where restart data is stored 
    ! runname_save = runname  ! the working folder has the restart data 
    loc_runname_save = '../'//trim(adjustl(runname_save))//'/'//trim(adjustl(profdir(3:)))
    if (trim(adjustl(runname_save)) == 'self') loc_runname_save = trim(adjustl(profdir))
    call system('cp '//trim(adjustl(loc_runname_save))//'/'//'prof_sld-save.txt '  &
        & //trim(adjustl(profdir))//'/'//'prof_sld-restart.txt')
    call system('cp '//trim(adjustl(loc_runname_save))//'/'//'prof_aq-save.txt '  &
        & //trim(adjustl(profdir))//'/'//'prof_aq-restart.txt')
    call system('cp '//trim(adjustl(loc_runname_save))//'/'//'prof_gas-save.txt '  &
        & //trim(adjustl(profdir))//'/'//'prof_gas-restart.txt')
    call system('cp '//trim(adjustl(loc_runname_save))//'/'//'bsd-save.txt '  &
        & //trim(adjustl(profdir))//'/'//'bsd-restart.txt')
    call system('cp '//trim(adjustl(loc_runname_save))//'/'//'psd-save.txt '  &
        & //trim(adjustl(profdir))//'/'//'psd-restart.txt')
        
    call get_saved_variables_num( &
        & workdir,loc_runname_save &! input
        & ,nsp_aq_save,nsp_sld_save,nsp_gas_save,nrxn_ext_save,nsld_kinspc_save &! output
        & )
    
    allocate(chraq_save(nsp_aq_save),chrsld_save(nsp_sld_save),chrgas_save(nsp_gas_save),chrrxn_ext_save(nrxn_ext_save))
    allocate(maq_save(nsp_aq_save,nz),msld_save(nsp_sld_save,nz),mgas_save(nsp_gas_save,nz))
    allocate(chrsld_kinspc_save(nsld_kinspc_save),kin_sldspc_save(nsld_kinspc_save))
        
    
    call get_saved_variables( &
        & workdir,loc_runname_save &! input
        & ,nsp_aq_save,nsp_sld_save,nsp_gas_save,nrxn_ext_save,nsld_kinspc_save &! input
        & ,chraq_save,chrgas_save,chrsld_save,chrrxn_ext_save,chrsld_kinspc_save,kin_sldspc_save &! output
        & )
    
        
    open (isldprof, file=trim(adjustl(profdir))//'/'//'prof_sld-restart.txt',  &
        & status ='old',action='read')
    open (iaqprof, file=trim(adjustl(profdir))//'/'//'prof_aq-restart.txt',  &
        & status ='old',action='read')
    open (igasprof, file=trim(adjustl(profdir))//'/'//'prof_gas-restart.txt',  &
        & status ='old',action='read')
    open (ibsd, file=trim(adjustl(profdir))//'/'//'bsd-restart.txt',  &
        & status ='old',action='read')
    open (ipsd, file=trim(adjustl(profdir))//'/'//'psd-restart.txt',  &
        & status ='old',action='read')
    
    read (isldprof,'()')
    read (iaqprof,'()')
    read (igasprof,'()')
    read (ibsd,'()')
    read (ipsd,'()')
    
    do iz = 1, Nz
        ucvsld1 = 1d0
        if (msldunit == 'blk') ucvsld1 = 1d0 - poro(iz)
        read (isldprof,*) z(iz),(msld_save(isps,iz),isps=1,nsp_sld_save),time
        read (iaqprof,*) z(iz),(maq_save(ispa,iz),ispa=1,nsp_aq_save),pro(iz),time
        read (igasprof,*) z(iz),(mgas_save(ispg,iz),ispg=1,nsp_gas_save),time
        read (ibsd,*) z(iz),poro(iz),sat(iz),v(iz),hr(iz),w(iz),sldvolfrac(iz),rho_grain_z(iz),mblk(iz),time
        read (ipsd,*) z(iz), (psd(ips,iz),ips=1,nps), time 
        mblk(iz) = mblk(iz)/ ( mwtblk*1d2/ucvsld1/(rho_grain_z(iz)*1d6) )
    enddo 
    close(isldprof)
    close(iaqprof)
    close(igasprof)
    close(ibsd)
    close(ipsd)

    pro = 10d0**(-pro) ! read data is -log10 (pro)
    time = 0d0
    
    torg = poro**(3.4d0-2.0d0)*(1.0d0-sat)**(3.4d0-1.0d0)
    tora = poro**(3.4d0-2.0d0)*(sat)**(3.4d0-1.0d0)
    
    do isps = 1,nsp_sld_save
        if (any(chrsld == chrsld_save(isps))) then 
            msld(findloc(chrsld,chrsld_save(isps),dim=1),:) = msld_save(isps,:)
        elseif (any(chrsld_cnst == chrsld_save(isps))) then
            msldc(findloc(chrsld_cnst,chrsld_save(isps),dim=1),:) = msld_save(isps,:)
        else 
            print *,'error in re-assignment of sld conc.'
        endif 
    enddo 
    
    do ispa = 1,nsp_aq_save
        if (any(chraq == chraq_save(ispa))) then 
            maq(findloc(chraq,chraq_save(ispa),dim=1),:) = maq_save(ispa,:)
        elseif (any(chraq_cnst == chraq_save(ispa))) then
            maqc(findloc(chraq_cnst,chraq_save(ispa),dim=1),:) = maq_save(ispa,:)
        else 
            print *,'error in re-assignment of aq conc.'
        endif 
    enddo 
    
    do ispg = 1,nsp_gas_save
        if (any(chrgas == chrgas_save(ispg))) then 
            mgas(findloc(chrgas,chrgas_save(ispg),dim=1),:) = mgas_save(ispg,:)
        elseif (any(chrgas_cnst == chrgas_save(ispg))) then
            mgasc(findloc(chrgas_cnst,chrgas_save(ispg),dim=1),:) = mgas_save(ispg,:)
        else 
            print *,'error in re-assignment of gas conc.'
        endif 
    enddo 
    
    ! counting sld species whose values are to be specificed in kinspc.save and not so yet when reading from kinspc.in
    nsld_kinspc_add = 0
    do isps_kinspc = 1,nsld_kinspc_save
        if (any(chrsld_kinspc_in == chrsld_kinspc_save(isps_kinspc))) then ! already specified 
            continue
        else 
            nsld_kinspc_add = nsld_kinspc_add + 1
        endif 
    enddo 
    
    if (nsld_kinspc_add > 0) then 
        ! deallocate 
        if (allocated(kin_sld_spc)) deallocate (kin_sld_spc)
        if (allocated(chrsld_kinspc)) deallocate (chrsld_kinspc)
        ! re-define sld species number whose rate const. is specified 
        nsld_kinspc = nsld_kinspc + nsld_kinspc_add
        ! allocate 
        allocate(kin_sld_spc(nsld_kinspc),chrsld_kinspc(nsld_kinspc))
        ! saving already specified consts. 
        chrsld_kinspc(1:nsld_kinspc_in) = chrsld_kinspc_in
        kin_sld_spc(1:nsld_kinspc_in) = kin_sld_spc_in
        ! adding previously specified rate const. 
        nsld_kinspc_add = 0
        do isps_kinspc = 1,nsld_kinspc_save
            if (any(chrsld_kinspc_in == chrsld_kinspc_save(isps_kinspc))) then 
                continue
            else 
                nsld_kinspc_add = nsld_kinspc_add + 1
                chrsld_kinspc(nsld_kinspc_in + nsld_kinspc_add) = chrsld_kinspc_save(isps_kinspc)
                kin_sld_spc(nsld_kinspc_in + nsld_kinspc_add) = kin_sldspc_save(isps_kinspc)
            endif 
        enddo 
    endif 
    
    ! just to obtain so4f 
    print_cb = .false. 
    print_loc = './ph.txt'
    
    call calc_pH_v7_3( &
        & nz,kw,nsp_aq,nsp_gas,nsp_aq_all,nsp_gas_all,nsp_aq_cnst,nsp_gas_cnst &! input 
        & ,chraq,chraq_cnst,chraq_all,chrgas,chrgas_cnst,chrgas_all &!input
        & ,maq,maqc,mgas,mgasc,keqgas_h,keqaq_h,keqaq_c,keqaq_s,maqth_all,keqaq_no3,keqaq_nh3 &! input
        & ,print_cb,print_loc,z &! input 
        & ,dprodmaq_all,dprodmgas_all,dso4fdmaq_all,dso4fdmgas_all &! output
        & ,prox,ph_error,so4f,ph_iter &! output
        & ) 
    so4fprev = so4f
        
    if (display) then
        write(chrfmt,'(i0)') nz_disp
        chrfmt = '(a5,'//trim(adjustl(chrfmt))//'(1x,E11.3))'
        
        print *
        print *,' [concs] '
        print trim(adjustl(chrfmt)),'z',(z(iz),iz=1,nz,nz/nz_disp)
        if (nsp_aq>0) then 
            print *,' < aq species >'
            do ispa = 1, nsp_aq
                print trim(adjustl(chrfmt)), trim(adjustl(chraq(ispa))), (maq(ispa,iz),iz=1,nz, nz/nz_disp)
            enddo 
        endif 
        if (nsp_sld>0) then 
            print *,' < sld species >'
            do isps = 1, nsp_sld
                print trim(adjustl(chrfmt)), trim(adjustl(chrsld(isps))), (msld(isps,iz),iz=1,nz, nz/nz_disp)
            enddo 
        endif 
        if (nsp_gas>0) then 
            print *,' < gas species >'
            do ispg = 1, nsp_gas
                print trim(adjustl(chrfmt)), trim(adjustl(chrgas(ispg))), (mgas(ispg,iz),iz=1,nz, nz/nz_disp)
            enddo 
        endif 
    endif      
endif
    
call coefs_v2( &
    & nz,rg,rg2,tc,sec2yr,tempk_0,pro,poro,hr &! input
    & ,nsp_aq_all,nsp_gas_all,nsp_sld_all,nrxn_ext_all &! input
    & ,chraq_all,chrgas_all,chrsld_all,chrrxn_ext_all &! input
    & ,nsp_gas,nsp_gas_cnst,chrgas,chrgas_cnst,mgas,mgasc,mgasth_all,mv_all,staq_all &!input
    & ,ucv,kw,daq_all,dgasa_all,dgasg_all,keqgas_h,keqaq_h,keqaq_c,keqaq_s,keqaq_no3,keqaq_nh3 &! output
    & ,ksld_all,keqsld_all,krxn1_ext_all,krxn2_ext_all &! output
    & ) 
    
! zml_ref = 1.5d0 ! mixed layer depth [m]
! zml_ref = 0.5d0 ! mixed layer depth [m]
dbl_ref = 0d0  
labs = .false.
turbo2 = .false.
nobio = .false.
till = .false.
    
if (no_biot) nobio = .true.
if (biot_turbo2) turbo2 = .true.
if (biot_fick) fick = .true.
if (biot_labs) labs = .true.
if (biot_till) till = .true.

save_trans = .true.
save_trans = .false.
call make_transmx(  &
    & labs,nsp_sld,turbo2,nobio,dz,poro,nz,z,zml_ref,dbl_ref,fick,till,tol,save_trans  &! input
    & ,trans,nonlocal,izml  &! output 
    & )
    
! --------- loop -----
print *, 'about to start time loop'
it = 0
irec = 0

ict = 0
ict_prev = ict
ict_change = .false.

count_dtunchanged = 0

!! @@@@@@@@@@@@@@@   start of time integration  @@@@@@@@@@@@@@@@@@@@@@

do while (it<nt)
    ! call cpu_time(time_start)
    call system_clock(t1)
    
    if (display) then 
        print *
        print *, '-----------------------------------------'
        print '(i11,a)', it,': time iteration'
        print '(E11.3,a)',time,': time [yr]' 
        print *
    endif
    dt_prev = dt
    
    if (time>rectime(nrec)) exit
    
    if (it == 0) then 
        maxdt = 0.2d0
    endif 
    
    if (timestep_fixed) then 
        maxdt = 0.2d0
        ! maxdt = 0.02d0 ! when calcite is included smaller time step must be assumed 
        ! maxdt = 0.005d0 ! when calcite is included smaller time step must be assumed 
        ! maxdt = 0.002d0 ! working with p80 = 10 um
        ! maxdt = 0.001d0 ! when calcite is included smaller time step must be assumed 
        ! maxdt = 0.0005d0 ! working with p80 = 1 um
        
        ! if (time<1d-2) then  
            ! maxdt = 1d-6 
        ! elseif (time>=1d-2 .and. time<1d-1) then 
        ! if (time<1d-3) then  
            ! maxdt = 1d-7 
        ! elseif (time>=1d-3 .and. time<1d-2) then  
            ! maxdt = 1d-6 
        ! elseif (time>=1d-2 .and. time<1d-1) then  
            ! maxdt = 1d-5 
        ! elseif (time>=1d-1 .and. time<1d0) then  
        if ( time<1d0) then  
            maxdt = 1d-4 
        elseif (time>=1d0 .and. time<1d1) then 
            maxdt = 1d-3 
        elseif (time>=1d1 .and. time<1d2) then 
            maxdt = 1d-2  
        ! elseif (time>=1d2 .and. time<1d3) then 
            ! maxdt = 1d-1 
        ! elseif (time>=1d3 .and. time<1d4) then 
            ! maxdt = 1d0 
        ! elseif (time>=1d4 .and. time<1d5) then 
            ! maxdt = 1d1 
        ! elseif (time>=1d5 ) then 
            ! maxdt = 1d2 
        endif 
        
        ! maxdt = maxdt * 1d-1
    endif 
    
    ! count_dtunchanged_Max = 1000
    ! count_dtunchanged_Max = 10
    ! if (sld_enforce) count_dtunchanged_Max = 10
    ! if (dt<1d-5) then 
        ! count_dtunchanged_Max = 10
    ! elseif (dt>=1d-5 .and. dt<1d0) then
        ! count_dtunchanged_Max = 100
    ! elseif (dt>=1d0 ) then 
        ! count_dtunchanged_Max = 1000
    ! endif 

    ! -------- modifying dt --------

    !        if ((iter <= 10).and.(dt<1d1)) then
    if (dt<maxdt) then
        ! dt = dt*1.01d0
        dt = dt*10d0
        if (dt>maxdt) dt = maxdt
    endif
    ! if (iter > 300) then
        ! dt = dt/10d0
    ! end if
    
    ! if (dt/=dt_prev) pre_calc = .true.

    ! incase temperature&ph change
    
    ! if climate is changing in the model 
    if (any(climate)) then 
        ict_change = .false.
        do iclim = 1,3
            if (climate(iclim)) then
                select case(iclim)
                    case(1)
                        if (dt > dct(iclim)/10d0) dt = dct(iclim)/10d0
                        do ict = 1, nclim(iclim)
                            print *, clim_T(1,ict),mod(time,ctau(iclim)),clim_T(1,ict) + dct(iclim)
                            if ( &
                                & clim_T(1,ict) <= mod(time,ctau(iclim)) & 
                                & .and. clim_T(1,ict) + dct(iclim) >= mod(time,ctau(iclim)) &
                                & ) then 
                                ! if (  &
                                    ! & mod(time,ctau(iclim)) + dt - clim_T(1,ict) + dct(iclim) &
                                    ! & > ctau(iclim) * tol_step_tau &
                                    ! & ) then 
                                    ! dt = clim_T(1,ict) + dct(iclim) - mod(time,ctau(iclim))
                                ! endif 
                                print *, ict
                                if (ict /= ict_prev(iclim)) ict_change(iclim) = .true.
                                ict_prev(iclim) = ict
                                exit 
                            endif 
                        enddo 
                        if (ict /= nclim(iclim)) then 
                            tc = ( clim_T(2,ict+1) - clim_T(2,ict) ) /( clim_T(1,ict+1) - clim_T(1,ict) ) &
                                & * ( mod(time,ctau(iclim)) - clim_T(1,ict) ) + clim_T(2,ict)
                        elseif (ict == nclim(iclim)) then 
                            tc = ( clim_T(2,1) - clim_T(2,ict) ) /( dct(iclim)  ) &
                                & * ( mod(time,ctau(iclim)) - clim_T(1,ict) ) + clim_T(2,ict)
                        endif 
                        
                    case(2)
                        if (dt > dct(iclim)/10d0) dt = dct(iclim)/10d0
                        do ict = 1, nclim(iclim)
                            print *, clim_q(1,ict),mod(time,ctau(iclim)),clim_q(1,ict) + dct(iclim)
                            if ( &
                                & clim_q(1,ict) <= mod(time,ctau(iclim)) & 
                                & .and. clim_q(1,ict) + dct(iclim) >= mod(time,ctau(iclim)) &
                                & ) then 
                                ! if (  &
                                    ! & mod(time,ctau(iclim)) + dt - clim_q(1,ict) + dct(iclim) &
                                    ! & > ctau(iclim) * tol_step_tau &
                                    ! & ) then 
                                    ! dt = clim_q(1,ict) + dct(iclim) - mod(time,ctau(iclim))
                                ! endif 
                                print *, ict
                                if (ict /= ict_prev(iclim)) ict_change(iclim) = .true.
                                ict_prev(iclim) = ict
                                exit 
                            endif 
                        enddo 
                        if (ict /= nclim(iclim)) then 
                            qin = ( clim_q(2,ict+1) - clim_q(2,ict) ) /( clim_q(1,ict+1) - clim_q(1,ict) ) &
                                & * ( mod(time,ctau(iclim)) - clim_q(1,ict) ) + clim_q(2,ict)
                        elseif (ict == nclim(iclim)) then 
                            qin = ( clim_q(2,1) - clim_q(2,ict) ) /( dct(iclim)  ) &
                                & * ( mod(time,ctau(iclim)) - clim_q(1,ict) ) + clim_q(2,ict)
                        endif 
                        
                    case(3)
                        if (dt > dct(iclim)/10d0) dt = dct(iclim)/10d0
                        do ict = 1, nclim(iclim)
                            print *, clim_sat(1,ict),mod(time,ctau(iclim)),clim_sat(1,ict) + dct(iclim)
                            if ( &
                                & clim_sat(1,ict) <= mod(time,ctau(iclim)) & 
                                & .and. clim_sat(1,ict) + dct(iclim) >= mod(time,ctau(iclim)) &
                                & ) then 
                                ! if (  &
                                    ! & mod(time,ctau(iclim)) + dt - clim_sat(1,ict) + dct(iclim) &
                                    ! & > ctau(iclim) * tol_step_tau &
                                    ! & ) then 
                                    ! dt = clim_sat(1,ict) + dct(iclim) - mod(time,ctau(iclim))
                                ! endif 
                                print *, ict
                                if (ict /= ict_prev(iclim)) ict_change(iclim) = .true.
                                ict_prev(iclim) = ict
                                exit 
                            endif 
                        enddo 
                        if (ict /= nclim(iclim)) then 
                            satup = ( clim_sat(2,ict+1) - clim_sat(2,ict) ) /( clim_sat(1,ict+1) - clim_sat(1,ict) ) &
                                & * ( mod(time,ctau(iclim)) - clim_sat(1,ict) ) + clim_sat(2,ict)
                        elseif (ict == nclim(iclim)) then 
                            satup = ( clim_sat(2,1) - clim_sat(2,ict) ) /( dct(iclim)  ) &
                                & * ( mod(time,ctau(iclim)) - clim_sat(1,ict) ) + clim_sat(2,ict)
                        endif 
                endselect
            endif 
        enddo 
        if (dt >= minval(dct)/10d0 .or. any (ict_change) ) then 
            open(idust, file=trim(adjustl(flxdir))//'/'//'climate.txt', &
                & status='old',action='write',position='append')
            write(idust,*) time,tc,qin,satup
            close(idust)
        endif 
        
        sat = min(1.0d0, 1d0-(1d0-satup)*(1d0-z/zsat)**2d0)
        do iz=1,nz
            if (z(iz)>=zsat) sat(iz)=1d0
        enddo 
        v = qin/poroi/sat
        torg = poro**(3.4d0-2.0d0)*(1.0d0-sat)**(3.4d0-1.0d0)
        tora = poro**(3.4d0-2.0d0)*(sat)**(3.4d0-1.0d0)
        
    endif 
        
    call coefs_v2( &
        & nz,rg,rg2,tc,sec2yr,tempk_0,pro,poro,hr &! input
        & ,nsp_aq_all,nsp_gas_all,nsp_sld_all,nrxn_ext_all &! input
        & ,chraq_all,chrgas_all,chrsld_all,chrrxn_ext_all &! input
        & ,nsp_gas,nsp_gas_cnst,chrgas,chrgas_cnst,mgas,mgasc,mgasth_all,mv_all,staq_all &!input
        & ,ucv,kw,daq_all,dgasa_all,dgasg_all,keqgas_h,keqaq_h,keqaq_c,keqaq_s,keqaq_no3,keqaq_nh3 &! output
        & ,ksld_all,keqsld_all,krxn1_ext_all,krxn2_ext_all &! output
        & ) 
    
    do isps = 1, nsp_sld
        ksld(isps,:) = ksld_all(findloc(chrsld_all,chrsld(isps),dim=1),:)
        ! print *,chrsld(isps),ksld(isps,:)
    enddo
    
    do ispa = 1, nsp_aq 
        daq(ispa) = daq_all(findloc(chraq_all,chraq(ispa),dim=1))
    enddo 
    
    do ispg = 1, nsp_gas 
        dgasa(ispg) = dgasa_all(findloc(chrgas_all,chrgas(ispg),dim=1))
        dgasg(ispg) = dgasg_all(findloc(chrgas_all,chrgas(ispg),dim=1))
    enddo 
    kho = keqgas_h(findloc(chrgas_all,'po2',dim=1),ieqgas_h0)
    kco2 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h0)
    knh3 = keqgas_h(findloc(chrgas_all,'pnh3',dim=1),ieqgas_h0)
    kn2o = keqgas_h(findloc(chrgas_all,'pn2o',dim=1),ieqgas_h0)
    k1 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h1)
    k2 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h2)
    k1nh3 = keqgas_h(findloc(chrgas_all,'pnh3',dim=1),ieqgas_h1)
    pco2i = mgasi_all(findloc(chrgas_all,'pco2',dim=1))
    pnh3i = mgasi_all(findloc(chrgas_all,'pnh3',dim=1))
    khco2i = kco2*(1d0+k1/proi + k1*k2/proi/proi)
    khnh3i = knh3*(1d0+proi/k1nh3)

    do ispg = 1, nsp_gas 
        select case(trim(adjustl(chrgas(ispg)))) 
            case('pco2')
                khgasi(ispg) = khco2i
            case('po2')
                khgasi(ispg) = kho
            case('pnh3')  
                khgasi(ispg) = khnh3i
            case('pn2o')  
                khgasi(ispg) = kn2o
        endselect 
    enddo
    
    ! print*,khgasi,knh3,k1nh3
    ! pause
    
    ! kinetic inhibition 
    if (al_inhibit) then 
        if (any(chraq == 'al')) then 
            do isps = 1, nsp_sld
                if (staq(isps,findloc(chraq,'al',dim=1)) .ne. 0d0) then 
                    ksld(isps,:) = ksld(isps,:) &
                        & *10d0**(-4.84d0)/(10d0**(-4.84d0)+maq(findloc(chraq,'al',dim=1),:)) 
                endif 
            enddo 
        endif 
    endif 
    
    ! nobio = .true.
    save_trans = .false.
    call make_transmx(  &
        & labs,nsp_sld,turbo2,nobio,dz,poro,nz,z,zml_ref,dbl_ref,fick,till,tol,save_trans  &! input
        & ,trans,nonlocal,izml  &! output 
        & )


    error = 1d4
    ! iter=0

100 continue

    mgasx = mgas
    msldx = msld
    maqx = maq
    
    prox = pro  
    
    so4f = so4fprev
    
    poroprev = poro
    hrprev = hr
    vprev = v
    torgprev = torg
    toraprev = tora
    wprev = w 
    
    mblkx = mblk
    
    ! whether or not you are using psd
    psd_old = psd
    psd_error_flg = .false.

    !  raining dust & OM 
    maqsupp = 0d0
    mgassupp = 0d0
    do isps = 1, nsp_sld
        if (no_biot) then 
            msldsupp(isps,:) = rainpowder*rfrc_sld(isps)*exp(-z/zsupp)/zsupp
        else 
            msldsupp(isps,1) = rainpowder*rfrc_sld(isps)/dz(1)
        endif 
    enddo 
    
    ! dust options check 
    if (dust_wave .and. dust_step) then 
        print *
        print *, 'CAUTION: options of dust_wave and dust_step are both ON'
        print * 
        stop
    endif 
    
    ! if defined wave function is imposed on dust 
    if (dust_wave) then 
        do isps = 1, nsp_sld
            if (no_biot) then 
                msldsupp(isps,:) = msldsupp(isps,:)*merge(2d0,0d0,nint(time/wave_tau)==floor(time/wave_tau))
            else 
                msldsupp(isps,1) = msldsupp(isps,1)*merge(2d0,0d0,nint(time/wave_tau)==floor(time/wave_tau))
            endif 
        enddo 
        if (time==0d0 .or. dust_norm /= merge(2d0,0d0,nint(time/wave_tau)==floor(time/wave_tau))) then
            open(idust, file=trim(adjustl(flxdir))//'/'//'dust.txt', &
                & status='old',action='write',position='append')
            write(idust,*) time-dt,dust_norm
            write(idust,*) time,merge(2d0,0d0,nint(time/wave_tau)==floor(time/wave_tau))
            dust_norm = merge(2d0,0d0,nint(time/wave_tau)==floor(time/wave_tau))
            close(idust)
        endif 
    endif 
    
    ! non continueous
    if (dust_step) then 
        
        dust_norm_prev = dust_norm
        
        if (dt > step_tau) then 
            dt = step_tau
            ! go to 100
        endif 
        
        if (time - floor(time) < step_tau .and. time + dt - floor(time) >= step_tau ) then 
            if ( abs (step_tau - ( time - floor(time) ) ) > step_tau * tol_step_tau ) then 
                dt = step_tau - ( time - floor(time) )
                ! go to 100
            endif 
        endif 
        
        if (time - floor(time) >= step_tau) then 
            ! print *, 'no dust time', time 
            msldsupp = 0d0
            dust_norm = 0d0
        else 
            ! print *, 'dust time !!', time 
            msldsupp = msldsupp/step_tau
            dust_norm = 1d0/step_tau
        endif 
        
        if ( dust_norm /= dust_norm_prev ) then
            open(idust, file=trim(adjustl(flxdir))//'/'//'dust.txt', &
                & status='old',action='write',position='append')
            write(idust,*) time-dt,dust_norm_prev
            write(idust,*) time,dust_norm
            close(idust)
        endif 
        
    endif 
    
    ! overload with OM rain 
    do isps = 1, nsp_sld
        if (no_biot) then 
            ! msldsupp(isps,:) = msldsupp(isps,:) &
                ! & + plant_rain/12d0/((1d0-poroi)*rho_grain*1d6) &! converting g_C/g_soil/yr to mol_C/m3_soil/yr
                ! & *1d0 &! assuming 1m depth to which plant C is supplied 
                ! & *rfrc_sld_plant(isps) &
                ! & *exp(-z/zsupp_plant)/zsupp_plant
            msldsupp(isps,:) = msldsupp(isps,:) &
                & + plant_rain/12d0*rfrc_sld_plant(isps)*exp(-z/zsupp_plant)/zsupp_plant ! when plant_
        else 
            msldsupp(isps,1) = msldsupp(isps,1) &
                & + plant_rain/12d0*rfrc_sld_plant(isps)/dz(1) ! when plant_rain is in g_C/m2/yr
        endif 
    enddo 
    ! when enforcing solid states without previous OM spin-up
    if (sld_enforce .and. (.not.read_data)) then 
        if (any(chrgas=='pco2')) then 
            ! mgassupp(findloc(chrgas,'pco2',dim=1),:) = plant_rain/12d0*exp(-z/zsupp_plant)/zsupp_plant
            mgassupp(findloc(chrgas,'pco2',dim=1),:) = plant_rain/12d0/ztot
        endif 
    endif 
    
    ! do PSD for raining dust & OM 
    if (do_psd) then 
        
        psu_rain_list = (/ log10(5d-6), log10(20d-6),  log10(50d-6), log10(70d-6) /)
        ! pssigma_rain_list = (/ 0.5d0,  0.5d0, 0.5d0 /)
        pssigma_rain_list = (/ 0.2d0, 0.2d0,  0.2d0, 0.2d0 /)

        open(ipsd,file = trim(adjustl(profdir))//'/'//'psd_rain.txt',status = 'replace')
        write(ipsd,*) ' depth\log10(radius) ', (ps(ips),ips=1,nps), 'dt'
        
        do iz = 1,nz
        
            ! rained particle distribution 
            if (read_data) then 
                psd_rain(:,iz) = 0d0
                do ips = 1, nps_rain_char
                    psu_rain = psu_rain_list(ips)
                    pssigma_rain = pssigma_rain_list(ips)
                    psd_rain(:,iz) = psd_rain(:,iz) &
                        & + 1d0/pssigma_rain/sqrt(2d0*pi)*exp( -0.5d0*( (ps(:) - psu_rain)/pssigma_rain )**2d0 )
                enddo 
            else
                psu_rain = log10(p80)
                pssigma_rain = 1d0
                pssigma_rain = ps_sigma_std
                psd_rain(:,iz) = 1d0/pssigma_rain/sqrt(2d0*pi)*exp( -0.5d0*( (ps(:) - psu_rain)/pssigma_rain )**2d0 )
            endif 
            ! to ensure sum is 1
            ! print *, sum(psd_rain*dps)
            psd_rain(:,iz) = psd_rain(:,iz)/sum(psd_rain(:,iz)*dps(:)) 
            ! print *, sum(psd_rain*dps)
            ! stop

            ! balance for volumes
            ! sum(msldsupp*mv*1d-6) *dt (m3/m3) must be equal to sum( 4/3(pi)r3 * psd_rain * dps) 
            ! where psd is number / bulk m3 / log r
            psd_rain(:,iz) = psd_rain(:,iz) * sum(msldsupp(:,iz)*mv(:)*1d-6)*dt &
                ! & /(1d0 - poroi)  &
                & /sum(4d0/3d0*pi*(10d0**ps(:))**3d0*psd_rain(:,iz)*dps(:))
                
            if ( abs( (sum(msldsupp(:,iz)*mv(:)*1d-6)*dt &
                ! & /(1d0 - poroi) &
                & - sum(4d0/3d0*pi*(10d0**ps(:))**3d0*psd_rain(:,iz)*dps(:))) &
                & / ( sum(msldsupp(:,iz)*mv(:)*1d-6)*dt &
                ! & /(1d0 - poroi) &
                & ) ) > tol) then 
                print *,iz, sum(msldsupp(:,iz)*mv(:)*1d-6)*dt &
                    ! & /(1d0 - poroi) &
                    & ,sum(4d0/3d0*pi*(10d0**ps(:))**3d0*psd_rain(:,iz)*dps(:))
                stop
            endif 
            
            write(ipsd,*) z(iz),(psd_rain(ips,iz),ips=1,nps), dt
        enddo 
        
        close(ipsd)
    endif 
    
    
    ! if (it==0) pre_calc = .true.
    if (method_precalc) pre_calc = .true.
    
    if (pre_calc) then 
    ! if (pre_calc .and. it ==0) then 
        pre_calc = .false.
        ! call precalc_po2_v2( &
            ! & nz,po2th,dt,ucv,kho,dz,dgaso,daqo,po2i,poro,sat,po2,torg,tora,v &! input 
            ! & ,po2x &! output 
            ! & )
        
        ! call precalc_pco2_v2( &
            ! & nz,pco2th,dt,ucv,khco2,dz,dgasc,daqc,pco2i,poro,sat,pco2,torg,tora,v,resp &! input 
            ! & ,pco2x &! output 
            ! & )

        ! mgas(findloc(chrgas,'pco2',dim=1),:)=pco2(:)
        ! mgas(findloc(chrgas,'po2',dim=1),:)=po2(:)
        
        call precalc_gases( &
            & nz,dt,ucv,dz,poro,sat,torg,tora,v,prox &! input 
            & ,nsp_gas,nsp_gas_all,chrgas,chrgas_all,keqgas_h,mgasi,mgasth,mgas &! input
            & ,nrxn_ext,chrrxn_ext,rxnext,dgasa,dgasg,stgas_ext &! input
            & ,mgasx &! output 
            & )
            
        ! call precalc_gases_v2( &
            ! & nz,dt,ucv,dz,poro,sat,torg,tora,v,prox,hr &! input 
            ! & ,nsp_gas,nsp_gas_all,chrgas,chrgas_all,keqgas_h,mgasi,mgasth,mgas &! input
            ! & ,nrxn_ext,chrrxn_ext,rxnext,dgasa,dgasg,stgas_ext &! input
            ! & ,nsp_sld,stgas,mv,ksld,msld,omega,nonprec &! input
            ! & ,mgasx &! output 
            ! & )
        
        ! call precalc_slds( &
            ! & nz,msth,dt,w,dz,msili,msi,mfoi,mabi,mani,mcci,msilth,mabth,manth,mfoth,mccth   &! input
            ! & ,ms,msil,msilsupp,mfo,mfosupp,mab,mabsupp,mansupp,man,mcc,mccsupp,kcc,omega_cc,mvcc &! input
            ! & ,poro,hr,kcca,omega_cca,authig,sat,kka,mkai,mkath,omega_ka,mvka,mkasupp,mka &! input
            ! & ,msx,msilx,mfox,mabx,manx,mccx,mkax &! output
            ! & )
        
        ! msld(findloc(chrsld,'fo',dim=1),:)=mfo(:)
        ! msld(findloc(chrsld,'ab',dim=1),:)=mab(:)
        ! msld(findloc(chrsld,'an',dim=1),:)=man(:)
        ! msld(findloc(chrsld,'cc',dim=1),:)=mcc(:)
        ! msld(findloc(chrsld,'ka',dim=1),:)=mka(:)
        
        ! call precalc_slds_v2( &
            ! & nz,dt,w,dz,poro,hr,sat &! input
            ! & ,nsp_sld,nsp_sld_2,chrsld,chrsld_2,msldth,msldi,mv,msld,msldsupp,ksld,omega &! input
            ! & ,nrxn_ext,rxnext,stsld_ext &!input
            ! & ,msldx &! output
            ! & )
            
        call precalc_slds_v2_1( &
            & nz,dt,w0,dz,poro,hr,sat &! input
            & ,nsp_sld,nsp_sld_2,chrsld,chrsld_2,msldth,msldi,mv,msld,msldsupp,ksld,omega &! input
            & ,nrxn_ext,rxnext,stsld_ext &!input
            & ,labs,turbo2,trans &! input
            & ,msldx &! output
            & )
            
        ! call precalc_slds_v3( &
            ! & nz,dt,w,dz,poro,hr,sat &! input
            ! & ,nsp_sld,msldth,msldi,mv,msld,msldsupp,ksld,omega,nonprec &! input
            ! & ,msldx &! output
            ! & )
            
        ! call precalc_slds_v3_1( &
            ! & nz,dt,w,dz,poro,hr,sat &! input
            ! & ,nsp_sld,msldth,msldi,mv,msld,msldsupp,ksld,omega,nonprec &! input
            ! & ,labs,turbo2,trans &! input
            ! & ,msldx &! output
            ! & )

        ! pause
        
        ! call precalc_pw_sil_v2( &
            ! & nz,nath,mgth,cath,sith,dt,v,na,ca,mg,si,dz,dna,dsi,dmg,dca,tora,poro,sat,nai,mgi,cai,sii &! input 
            ! & ,kab,kan,kcc,kfo,hr,mvab,mvan,mvfo,mvcc,mabx,manx,mfox,mccx,alth,al,dal,ali,kka,mvka,mkax &! input 
            ! & ,nax,six,cax,mgx,alx &! output
            ! & )

        ! maq(findloc(chraq,'mg',dim=1),:)=mg(:)
        ! maq(findloc(chraq,'si',dim=1),:)=si(:)
        ! maq(findloc(chraq,'na',dim=1),:)=na(:)
        ! maq(findloc(chraq,'ca',dim=1),:)=ca(:)
        ! maq(findloc(chraq,'al',dim=1),:)=al(:)

        call precalc_aqs( &
            & nz,dt,v,dz,tora,poro,sat,hr &! input 
            & ,nsp_aq,nsp_sld,daq,maqth,maqi,maq,mv,msldx,ksld,staq &! input
            & ,nrxn_ext,staq_ext,rxnext &! input
            & ,maqx &! output
            & )
            
        ! call precalc_aqs_v2( &
            ! & nz,dt,v,dz,tora,poro,sat,hr &! input 
            ! & ,nsp_aq,nsp_sld,daq,maqth,maqi,maq,mv,msldx,ksld,staq,omega,nonprec &! input
            ! & ,nrxn_ext,staq_ext,rxnext &! input
            ! & ,maqx &! output
            ! & )

        if (any(isnan(mgasx)).or.any(isnan(msldx)).or.any(isnan(maqx))) then 
            print*, 'error in precalc'
            stop
        endif

    end if

    ! if ((.not.read_data) .and. it == 0 .and. iter == 0) then 
        ! do ispa = 1, nsp_aq
            ! if (chraq(ispa)/='so4') then
                ! maqx(ispa,1:) = 1d2
            ! endif 
        ! enddo
    ! endif 
    
    poro_iter = 0
    poro_error = 1d4
    poro_tol = 1d-6
    poro_iter_max = 50
    
! #ifdef poroiter
    poro_tol = 1d-9
    ! if (iwtype == iwtype_flex) poro_tol = 1d-14
    do while (poro_error > poro_tol) ! start of porosity iteration 
! #endif 

    porox = poro
    wx = w
    
    call alsilicate_aq_gas_1D_v3_1( &
        ! new input 
        & nz,nsp_sld,nsp_sld_2,nsp_aq,nsp_aq_ph,nsp_gas_ph,nsp_gas,nsp3,nrxn_ext &
        & ,chrsld,chrsld_2,chraq,chraq_ph,chrgas_ph,chrgas,chrrxn_ext  &
        & ,msldi,msldth,mv,maqi,maqth,daq,mgasi,mgasth,dgasa,dgasg,khgasi &
        & ,staq,stgas,msld,ksld,msldsupp,maq,maqsupp,mgas,mgassupp &
        & ,stgas_ext,stgas_dext,staq_ext,stsld_ext,staq_dext,stsld_dext &
        & ,nsp_aq_all,nsp_gas_all,nsp_sld_all,nsp_aq_cnst,nsp_gas_cnst &
        & ,chraq_cnst,chraq_all,chrgas_cnst,chrgas_all,chrsld_all &
        & ,maqc,mgasc,keqgas_h,keqaq_h,keqaq_c,keqsld_all,keqaq_s,keqaq_no3,keqaq_nh3 &
        & ,nrxn_ext_all,chrrxn_ext_all,mgasth_all,maqth_all,krxn1_ext_all,krxn2_ext_all &
        & ,nsp_sld_cnst,chrsld_cnst,msldc,rho_grain,msldth_all,mv_all,staq_all,stgas_all &
        & ,turbo2,labs,trans,method_precalc,display,chrflx,sld_enforce &! input
        & ,nsld_kinspc,chrsld_kinspc,kin_sld_spc &! input
        !  old inputs
        & ,hr,poro,z,dz,w_btm,sat,pro,poroprev,tora,v,tol,it,nflx,kw,so4fprev & 
        & ,ucv,torg,cplprec,rg,tc,sec2yr,tempk_0,proi,poroi,up,dwn,cnr,adf,msldunit  &
        ! old inout
        & ,dt,flgback,w &    
        ! output 
        & ,msldx,omega,flx_sld,maqx,flx_aq,mgasx,flx_gas,rxnext,prox,nonprec,rxnsld,flx_co2sp,so4f & 
        & )
        
    save_trans = .false.
    call make_transmx(  &
        & labs,nsp_sld,turbo2,nobio,dz,poro,nz,z,zml_ref,dbl_ref,fick,till,tol,save_trans  &! input
        & ,trans,nonlocal,izml  &! output 
        & )
        
    ! sum(msldx*mv*1d-6) + mblkx*mvblk*1d-6 = 1d0 - poro
    if ( incld_blk ) then 
        do iz=1,nz
            mblkx(iz) = 1d0 - poro(iz) - sum(msldx(:,iz)*mv(:)*1d-6)
            mblkx(iz) = mblkx(iz)/(mvblk*1d-6)
        enddo 
    else 
        mblkx = 0d0
    endif 

    if (flgback) then 
        flgback = .false. 
        flgreducedt = .true.
        ! pre_calc = .true.
        dt = dt/1d1
        psd = psd_old
        poro = poroprev
        torg = torgprev
        tora = toraprev
        v = vprev
        hr = hrprev
        w = wprev
        call calcupwindscheme(  &
            up,dwn,cnr,adf & ! output 
            ,w,nz   & ! input &
            )
        go to 100
    endif    
    
    if (poroevol) then 
        ! poroprev = poro
! #ifdef surfssa
        ! mvab = mvab_save 
        ! mvan = mvan_save 
        ! mvcc = mvcc_save 
        ! mvfo = mvfo_save 
        ! mvka = mvka_save 
! #endif 
        ! poro = poroi + (mabi-mabx)*(mvab)*1d-6  &
            ! & +(mfoi-mfox)*(mvfo)*1d-6 &
            ! & +(mani-manx)*(mvan)*1d-6 &
            ! & +(mcci-mccx)*(mvcc)*1d-6 &
            ! & +(mkai-mkax)*(mvka)*1d-6 
        if (iwtype == iwtype_flex) then 
            poro = poroi
            ! not constant but calculated as defined (only applicable when unit of msld(x) is mol per bulk soil)
            do iz = 1,nz
                poro(iz) = 1d0 - sum(msldx(:,iz)*mv(:)*1d-6)
            enddo 
        else 
            call calc_poro( &
                & nz,nsp_sld,nflx,idif,irain &! in
                & ,flx_sld,mv,poroprev,w,poroi,w_btm,dz,tol,dt &! in
                & ,poro &! inout
                & )
        endif 
        ! poro = poroi
        ! do isps=1,nsp_sld
            ! poro = poro + (msldi(isps)-msldx(isps,:))*mv(isps)*1d-6
        ! enddo
        ! do iz=1,nz
            ! DV(iz) = 0d0
            ! do isps = 1,nsp_sld 
                ! DV(iz) = DV(iz) + ( flx_sld(isps, 4 + isps,iz) + flx_sld(isps, idif ,iz) + flx_sld(isps, irain ,iz) ) &
                    ! & *mv(isps)*1d-6*dt 
            ! enddo 
            ! poro(iz) = poroprev(iz) - DV(iz)
        ! enddo 
        
        if (any(poro<0d0)) then 
            print*,'negative porosity: stop'
            print*,poro
            
            flgback = .false. 
            flgreducedt = .true.
            ! pre_calc = .true.
            dt = dt/1d1
            psd = psd_old
            poro = poroprev
            torg = torgprev
            tora = toraprev
            v = vprev
            hr = hrprev
            w = wprev
            call calcupwindscheme(  &
                up,dwn,cnr,adf & ! output 
                ,w,nz   & ! input &
                )
            go to 100
            
            ! w = w*2d0
            ! go to 100
            stop
        endif 
        if (any(poro>1d0)) then 
            print*,'porosity exceeds 1: stop'
            print*,poro
            
            flgback = .false. 
            flgreducedt = .true.
            ! pre_calc = .true.
            dt = dt/1d1
            psd = psd_old
            poro = poroprev
            torg = torgprev
            tora = toraprev
            v = vprev
            hr = hrprev
            w = wprev
            call calcupwindscheme(  &
                up,dwn,cnr,adf & ! output 
                ,w,nz   & ! input &
                )
            go to 100
            
            ! w = w*2d0
            ! go to 100
            stop
        endif 
        
! #ifdef surfssa
        ! mvab = mwtab 
        ! mvan = mwtan 
        ! mvcc = mwtcc 
        ! mvfo = mwtfo 
        ! mvka = mwtka 
! #endif 
        v = qin/poro/sat
        torg = poro**(3.4d0-2.0d0)*(1.0d0-sat)**(3.4d0-1.0d0)
        tora = poro**(3.4d0-2.0d0)*(sat)**(3.4d0-1.0d0)
        
#ifndef calcw_full
        w(:) = w0 
        dwsporo = 0d0        
        wsporo = w_btm*(1d0 - poroi)
        if (noncnstw) then 
            ! w(:) = w0/(1d0-poro(:)) ! --- isovolumetric weathering?
            do iz=1,nz
                DV(iz) = 0d0
                do isps = 1,nsp_sld 
                    DV(iz) = DV(iz) + ( flx_sld(isps, 4 + isps,iz) + flx_sld(isps, idif ,iz) + flx_sld(isps, irain ,iz) ) &
                        & *mv(isps)*1d-6*dt 
                enddo 
                dwsporo(iz) = -( ( poro(iz) - poroprev(iz))/dt - DV(iz)/dt )
            enddo 
            
            do iz = nz,1,-1
                if (iz==nz) then 
                    ! (wsporo(iz+1) - wsporo(iz))/dz(iz) = dwsporo(iz)
                    wsporo(iz) =  w_btm*(1d0 - poroi) - dwsporo(iz)*dz(iz)
                else
                    wsporo(iz) =  wsporo(iz+1) - dwsporo(iz)*dz(iz)
                endif 
            enddo 
            ! wsporo = w * (1d0 - poro)
            w = wsporo/(1d0-poro)
        endif 
        
        wsporo = w_btm*(1d0 - poroi)
        w = wsporo/(1d0-poro)
        
        w = w_btm
        
        call calc_uplift( &
            & nz,nsp_sld,nflx,idif,irain &! IN
            & ,iwtype &! in
            & ,flx_sld,mv,poroi,w_btm,dz,poro,poroprev,dt &! in
            & ,w &! inout
            & )
        
        ! ------------ determine calculation scheme for advection (from IMP code)
        call calcupwindscheme(  &
            up,dwn,cnr,adf & ! output 
            ,w,nz   & ! input &
            )
#endif 
        
        hr = hri*rough
        if (surfevol1 ) then 
            hr = hri*rough*((1d0-poro)/(1d0-poroi))**(2d0/3d0)
        endif 
        if (surfevol2 ) then 
            hr = hri*rough*(poro/poroi)**(2d0/3d0)  ! SA increases with porosity 
        endif 
        ! if doing psd SA is calculated reflecting psd
        if (do_psd) then 
            ! hr = ssa*(1-poro)/poro ! converting m2/sld-m3 to m2/pore-m3
            ! hr = ssa
            hr = ssa/poro ! so that poro * hr * mv * msld becomes porosity independent 
        endif 
        
        if (display .and. (.not. display_lim)) then 
            write(chrfmt,'(i0)') nz_disp
            chrfmt = '(a5,'//trim(adjustl(chrfmt))//'(1x,E11.3))'
            print *
            print *,' [porosity & surface area]'
            print trim(adjustl(chrfmt)),'z',(z(iz),iz=1,nz,nz/nz_disp)
            print trim(adjustl(chrfmt)),'poro',(poro(iz),iz=1,nz, nz/nz_disp)
            print trim(adjustl(chrfmt)),'SA',(hr(iz),iz=1,nz, nz/nz_disp)
            print *
        endif 
    endif  
    
! #ifdef poroiter
    if (poroiter_in) then 
        if (iwtype == iwtype_flex) then 
            ! poro_error = maxval ( abs (( w - wx )/wx ) )
            poro_error = maxval ( abs ( w - wx ) )
        else
            ! poro_error = maxval ( abs (( poro - porox )/porox ) )
            poro_error = maxval ( abs ( poro - porox ) )
        endif 
        
        print *, 'porosity iteration: ',poro_iter,poro_error
        poro_iter = poro_iter + 1
                    
        if (poro_iter > poro_iter_max) then 
            print *, 'too much porosity iteration but does not converge within assumed threshold'
            print *, 'reducing dt and move back'
            flgback = .false. 
            flgreducedt = .true.
            psd = psd_old
            poro = poroprev
            torg = torgprev
            tora = toraprev
            v = vprev
            hr = hrprev
            w = wprev
            call calcupwindscheme(  &
                up,dwn,cnr,adf & ! output 
                ,w,nz   & ! input &
                )
            ! pre_calc = .true.
            dt = dt/1d1
            go to 100
        endif    
    else 
        poro_error = 0d0
        EXIT 
    endif 
    
    enddo ! porosity iteration end
! #endif 
    ! attempt to do psd
    if (do_psd) then 
        
        if (display) then 
            print *
            print *, '-- doing PSD'
        endif 
    
        dpsd = 0d0
        
        call psd_diss( &
            & nsp_sld,nps,nflx &! in
            & ,z,flx_sld,mv,dt,pi,tol,poro &! in 
            & ,incld_rough,rough_c0,rough_c1 &! in
            & ,profdir,ipsd &! in
            & ,ps,dps,ps_min,ps_max &! in 
            & ,psd,dpsd,psd_error_flg &! inout
            & )
            
        if (psd_error_flg) then 
            flgback = .false. 
            flgreducedt = .true.
            psd = psd_old
            poro = poroprev
            torg = torgprev
            tora = toraprev
            v = vprev
            hr = hrprev
            w = wprev
            call calcupwindscheme(  &
                up,dwn,cnr,adf & ! output 
                ,w,nz   & ! input &
                )
            dt = dt/1d1
            go to 100
        endif 
        
        ! call psd_adv( &
            ! & nsp_sld,nps,nflx,iadv &! in
            ! & ,z,flx_sld,mv,dt,pi,tol,w,w0,dz &! in 
            ! & ,profdir,ipsd &! in
            ! & ,ps,dps,psd_pr &! in 
            ! & ,psd,dpsd &! inout
            ! & )
        
        ! call psd_adv_implicit( &
            ! & nsp_sld,nps,nflx,iadv &! in
            ! & ,z,flx_sld,mv,dt,pi,tol,w,w0,dz &! in 
            ! & ,profdir,ipsd &! in
            ! & ,ps,dps,psd_pr &! in 
            ! & ,psd,dpsd &! inout
            ! & )
        
        ! call psd_dif( &
            ! & nsp_sld,nps,nflx,idif &! in
            ! & ,z,flx_sld,mv,dt,pi,tol &! in 
            ! & ,trans &! in
            ! & ,profdir,ipsd &! in
            ! & ,ps,dps &! in 
            ! & ,psd,dpsd &! inout
            ! & )
            
        ! call psd_dif_implicit( &
            ! & nsp_sld,nps,nflx,idif,iadv &! in
            ! & ,z,dz,flx_sld,mv,dt,pi,tol,w0,w,hr &! in 
            ! & ,incld_rough,rough_c0,rough_c1 &! in
            ! & ,trans &! in
            ! & ,msldx &! in
            ! & ,profdir,ipsd &! in
            ! & ,psd,psd_pr,ps,dps &! in  
            ! & ,flgback &! inout
            ! & ,psdx &! out
            ! & )
        if (do_psd_norm) then 
            do ips=1,nps
                psd_norm_fact(ips) = maxval(psd(ips,:))
                
                psd_norm(ips,:) = psd(ips,:) / psd_norm_fact(ips)
                psd_pr_norm(ips) = psd_pr(ips) / psd_norm_fact(ips)
                dpsd_norm(ips,:) = dpsd(ips,:) / psd_norm_fact(ips)
                psd_rain_norm(ips,:) = psd_rain(ips,:) / psd_norm_fact(ips)
            enddo 
            
            call psd_implicit_all_v2( &
                & nsp_sld,nps,nflx,idif,iadv,nflx_psd &! in
                & ,z,dz,flx_sld,mv,dt,pi,tol,w_btm,w,hr,poro,poroi,poroprev &! in 
                & ,incld_rough,rough_c0,rough_c1 &! in
                & ,trans &! in
                & ,msldx &! in
                & ,profdir,ipsd &! in
                & ,psd_norm,psd_pr_norm,ps,dps,dpsd_norm,psd_rain_norm &! in  
                & ,flgback &! inout
                & ,psdx_norm,flx_psd_norm &! out
                & )
                
            do ips=1,nps
                psdx(ips,:) = psdx_norm(ips,:)*psd_norm_fact(ips)
                flx_psd(ips,:,:) = flx_psd_norm(ips,:,:)*psd_norm_fact(ips)
            enddo 
        else
            
            call psd_implicit_all_v2( &
                & nsp_sld,nps,nflx,idif,iadv,nflx_psd &! in
                & ,z,dz,flx_sld,mv,dt,pi,tol,w_btm,w,hr,poro,poroi,poroprev &! in 
                & ,incld_rough,rough_c0,rough_c1 &! in
                & ,trans &! in
                & ,msldx &! in
                & ,profdir,ipsd &! in
                & ,psd,psd_pr,ps,dps,dpsd,psd_rain &! in  
                & ,flgback &! inout
                & ,psdx,flx_psd &! out
                & )
            
        endif 
            
        if (flgback) then 
            flgback = .false. 
            flgreducedt = .true.
            psd = psd_old
            poro = poroprev
            torg = torgprev
            tora = toraprev
            v = vprev
            hr = hrprev
            w = wprev
            call calcupwindscheme(  &
                up,dwn,cnr,adf & ! output 
                ,w,nz   & ! input &
                )
            ! pre_calc = .true.
            dt = dt/1d1
            go to 100
        endif    

        ! psd = psd + dpsd
        psd = psdx 

        if (any(isnan(psd))) then 
            print *, 'nan in psd'
            stop
        endif 
        if (any(psd<0d0)) then 
            error_psd = 0d0
            do iz = 1, nz
                do ips=1,nps
                    if (psd(ips,iz)<0d0) then 
                        ! print *, 'ips,iz,dpsd,psd',ips,iz,dpsd(ips,iz),psd(ips,iz)
                        error_psd = min(error_psd,psd(ips,iz))
                        psd(ips,iz) = 0d0
                    endif 
                enddo 
            enddo 
            if (abs(error_psd/maxval(psd)) > tol) then 
                print *, 'negative psd'
                flgback = .false. 
                flgreducedt = .true.
                psd = psd_old
                poro = poroprev
                torg = torgprev
                tora = toraprev
                v = vprev
                hr = hrprev
                w = wprev
                call calcupwindscheme(  &
                    up,dwn,cnr,adf & ! output 
                    ,w,nz   & ! input &
                    )
                dt = dt/1d1
                go to 100
            endif 
            ! stop
        endif 
        
        ! trancating small psd 
        where (psd < psd_th)  psd = psd_th
        ! do iz = 1, nz
            ! do ips=1,nps
                ! if (psd(ips,iz)>0d0 .and. psd(ips,iz) < psd_th) then 
                    ! psd(ips,iz) = psd_th
                ! endif 
            ! enddo 
        ! enddo 
        

        ! open(ipsd,file = trim(adjustl(profdir))//'/'//'psd_tmp.txt',status = 'replace')
        ! write(ipsd,*) ' depth\log10(radius) ', (ps(ips),ips=1,nps)
        ! do iz = 1, nz
            ! write(ipsd,*) z(iz),(psd(ips,iz),ips=1,nps)
        ! enddo 
        ! close(ipsd)
        
        if (display) then 
            print *, '-- ending PSD'
            print *
        endif 
    
    else 
        psd = 0d0
    endif 
        
    ! if doing psd SA is calculated reflecting psd
    if (do_psd) then 
        if (.not. incld_rough) then 
            do iz=1,nz
                hr(iz) = sum( 4d0*pi*(10d0**ps(:))**2d0*psd(:,iz)*dps(:))
            enddo 
        else 
            do iz=1,nz
                hr(iz) = sum( 4d0*pi*(10d0**ps(:))**2d0*rough_c0*(10d0**ps(:))**rough_c1*psd(:,iz)*dps(:))
            enddo 
        endif 
        ssa  = hr
        ! hr = ssa*(1-poro)/poro ! converting m2/sld-m3 to m2/pore-m3
        ! hr = ssa
        hr = ssa/poro ! so that poro * hr * mv * msld becomes porosity independent
        
    endif 
    
    if (any(poro < 1d-10)) then 
        print *, '***| too small porosity: going to end sim as likely ending up crogging '
        print *, '***| ... and no more reasonable simulation ... ! '
        stop
    endif 

    if (display  .and. (.not. display_lim)) then 
        write(chrfmt,'(i0)') nz_disp
        chrfmt = '(a5,'//trim(adjustl(chrfmt))//'(1x,E11.3))'
        
        print *
        print *,' [concs] '
        print trim(adjustl(chrfmt)),'z',(z(iz),iz=1,nz,nz/nz_disp)
        if (nsp_aq>0) then 
            print *,' < aq species >'
            do ispa = 1, nsp_aq
                print trim(adjustl(chrfmt)), trim(adjustl(chraq(ispa))), (maqx(ispa,iz),iz=1,nz, nz/nz_disp)
            enddo 
        endif 
        if (nsp_sld>0) then 
            print *,' < sld species >'
            do isps = 1, nsp_sld
                print trim(adjustl(chrfmt)), trim(adjustl(chrsld(isps))), (msldx(isps,iz),iz=1,nz, nz/nz_disp)
            enddo 
        endif 
        if (nsp_gas>0) then 
            print *,' < gas species >'
            do ispg = 1, nsp_gas
                print trim(adjustl(chrfmt)), trim(adjustl(chrgas(ispg))), (mgasx(ispg,iz),iz=1,nz, nz/nz_disp)
            enddo 
        endif 
        
        print *
        print *,' [saturation & pH] '
        if (nsp_sld>0) then 
            print *,' < sld species omega >'
            do isps = 1, nsp_sld
                print trim(adjustl(chrfmt)), trim(adjustl(chrsld(isps))), (omega(isps,iz),iz=1,nz, nz/nz_disp)
            enddo 
        endif 
        print *,' < pH >'
        print trim(adjustl(chrfmt)), 'ph', (-log10(prox(iz)),iz=1,nz, nz/nz_disp)
        
        
        
        write(chrfmt,'(i0)') nflx
        chrfmt = '(a5,'//trim(adjustl(chrfmt))//'(1x,a11))'
        
        print *
        print *,' [fluxes] '
        print trim(adjustl(chrfmt)),' ',(chrflx(iflx),iflx=1,nflx)
        
        write(chrfmt,'(i0)') nflx
        chrfmt = '(a5,'//trim(adjustl(chrfmt))//'(1x,E11.3))'
        if (nsp_aq>0) then 
            print *,' < aq species >'
            do ispa = 1, nsp_aq
                print trim(adjustl(chrfmt)), trim(adjustl(chraq(ispa))), (sum(flx_aq(ispa,iflx,:)*dz(:)),iflx=1,nflx)
            enddo 
        endif 
        if (nsp_sld>0) then 
            print *,' < sld species >'
            do isps = 1, nsp_sld
                print trim(adjustl(chrfmt)), trim(adjustl(chrsld(isps))), (sum(flx_sld(isps,iflx,:)*dz(:)),iflx=1,nflx)
            enddo 
        endif 
        if (nsp_gas>0) then 
            print *,' < gas species >'
            do ispg = 1, nsp_gas
                print trim(adjustl(chrfmt)), trim(adjustl(chrgas(ispg))), (sum(flx_gas(ispg,iflx,:)*dz(:)),iflx=1,nflx)
            enddo 
        endif 
        
        if (do_psd) then 
            write(chrfmt,'(i0)') nflx_psd
            chrfmt = '(a5,'//trim(adjustl(chrfmt))//'(1x,a11))'

            print *
            print *,' [fluxes -- PSD] '
            print trim(adjustl(chrfmt)),'rad','tflx','adv','dif','rain','rxn','res'

            write(chrfmt,'(i0)') nflx_psd
            chrfmt = '(f5.2,'//trim(adjustl(chrfmt))//'(1x,E11.3))'
            do ips = 1, nps
                print trim(adjustl(chrfmt)), ps(ips), (sum(flx_psd(ips,iflx,:)*dz(:)),iflx=1,nflx_psd)
            enddo 
        endif
        
! #ifdef disp_lim
        if (display_lim_in) display_lim = .true.
! #endif 
        
    endif 

    ! stop
#ifdef lim_minsld
    where (msldx < 1d-20)  msldx = 1d-20
#endif 
    
    mgas = mgasx
    maq = maqx
    msld = msldx
    
    pro = prox
    so4fprev = so4f
    
    mblk = mblkx
    
    do iz = 1, nz
        ! rho_grain_z(iz) = sum(msldx(:,iz)*mwt(:)*1d-6)
        ! sldvolfrac(iz) = sum(msldx(:,iz)*mv(:)*1d-6)
        ! accounting for blk soil
        rho_grain_z(iz) = sum(msldx(:,iz)*mwt(:)*1d-6) + mblkx(iz)*mwtblk*1d-6
        sldvolfrac(iz) = sum(msldx(:,iz)*mv(:)*1d-6) + mblkx(iz)*mvblk*1d-6
        
        if (msldunit=='blk') then 
            rho_grain_z(iz) = rho_grain_z(iz) / ( 1d0 - poro(iz) )
            sldvolfrac(iz) = sldvolfrac(iz) / ( 1d0 - poro(iz) )
        endif 
            
    enddo 

    if (time > savetime) then 
        
        open(isldprof,file=trim(adjustl(profdir))//'/' &
            & //'prof_sld-save.txt', status='replace')
        open(igasprof,file=trim(adjustl(profdir))//'/' &
            & //'prof_gas-save.txt', status='replace')
        open(iaqprof,file=trim(adjustl(profdir))//'/' &
            & //'prof_aq-save.txt', status='replace')
        open(ibsd, file=trim(adjustl(profdir))//'/'  &
            & //'bsd-save.txt', status='replace')
            
        write(isldprof,*) ' z ',(chrsld(isps),isps=1,nsp_sld),' time '
        write(iaqprof,*) ' z ',(chraq(isps),isps=1,nsp_aq),' ph ',' time '
        write(igasprof,*) ' z ',(chrgas(isps),isps=1,nsp_gas),' time '
        write(ibsd,*) ' z ',' poro ', ' sat ', ' v[m/yr] ', ' m2/m3 ' , ' w[m/yr] '  &
            & , ' vol[m3/m3] ',' dens[g/cm3] ', ' blk[wt%] ',' time '

        do iz = 1, Nz
            ucvsld1 = 1d0
            if (msldunit == 'blk') ucvsld1 = 1d0 - poro(iz)
            write(isldprof,*) z(iz),(msldx(isps,iz),isps = 1, nsp_sld),time
            write(igasprof,*) z(iz),(mgasx(isps,iz),isps = 1, nsp_gas),time
            write(iaqprof,*) z(iz),(maqx(isps,iz),isps = 1, nsp_aq),-log10(prox(iz)),time
            write(ibsd,*) z(iz), poro(iz),sat(iz),v(iz),hr(iz),w(iz),sldvolfrac(iz),rho_grain_z(iz) &
                & ,mblkx(iz)*mwtblk*1d2/ucvsld1/(rho_grain_z(iz)*1d6), time
        end do

        close(isldprof)
        close(iaqprof)
        close(igasprof)
        close(ibsd)
        
        if (do_psd) then 
            open(ipsd, file=trim(adjustl(profdir))//'/'  &
                & //'psd-save.txt', status='replace')
            write(ipsd,*) ' z[m]\log10(r[m]) ',(ps(ips),ips=1,nps),' time '
            do iz = 1, Nz
                write(ipsd,*) z(iz), (psd(ips,iz),ips=1,nps), time 
            end do
            close(ipsd)
        endif 
        
        savetime = savetime + dsavetime
        
    endif 

    if (time>=rectime(irec+1)) then
        write(chr,'(i3.3)') irec+1
        
        
        print_cb = .true. 
        print_loc = trim(adjustl(profdir))//'/' &
            & //'chrge_balance-'//chr//'.txt'

#ifdef phv7_2
        call calc_pH_v7_2( &
            & nz,kw,nsp_aq,nsp_gas,nsp_aq_all,nsp_gas_all,nsp_aq_cnst,nsp_gas_cnst &! input 
            & ,chraq,chraq_cnst,chraq_all,chrgas,chrgas_cnst,chrgas_all &!input
            & ,maqx,maqc,mgasx,mgasc,keqgas_h,keqaq_h,keqaq_c,keqaq_s,maqth_all,keqaq_no3,keqaq_nh3 &! input
            & ,print_cb,print_loc,z &! input 
            & ,prox,ph_error,so4f,ph_iter &! output
            & ) 
#else
        call calc_pH_v7_3( &
            & nz,kw,nsp_aq,nsp_gas,nsp_aq_all,nsp_gas_all,nsp_aq_cnst,nsp_gas_cnst &! input 
            & ,chraq,chraq_cnst,chraq_all,chrgas,chrgas_cnst,chrgas_all &!input
            & ,maqx,maqc,mgasx,mgasc,keqgas_h,keqaq_h,keqaq_c,keqaq_s,maqth_all,keqaq_no3,keqaq_nh3 &! input
            & ,print_cb,print_loc,z &! input 
            & ,dprodmaq_all,dprodmgas_all,dso4fdmaq_all,dso4fdmgas_all &! output
            & ,prox,ph_error,so4f,ph_iter &! output
            & ) 
#endif
        
        open(isldprof,file=trim(adjustl(profdir))//'/' &
            & //'prof_sld-'//chr//'.txt', status='replace')
        open(isldprof2,file=trim(adjustl(profdir))//'/' &
            & //'prof_sld(wt%)-'//chr//'.txt', status='replace')
        open(isldprof3,file=trim(adjustl(profdir))//'/' &
            & //'prof_sld(v%)-'//chr//'.txt', status='replace')
        open(isldsat,file=trim(adjustl(profdir))//'/' &
            & //'sat_sld-'//chr//'.txt', status='replace')
        open(igasprof,file=trim(adjustl(profdir))//'/' &
            & //'prof_gas-'//chr//'.txt', status='replace')
        open(iaqprof,file=trim(adjustl(profdir))//'/' &
            & //'prof_aq-'//chr//'.txt', status='replace')
        open(ibsd, file=trim(adjustl(profdir))//'/'  &
            & //'bsd-'//chr//'.txt', status='replace')
        open(irate, file=trim(adjustl(profdir))//'/'  &
            & //'rate-'//chr//'.txt', status='replace')
            
        write(chrfmt,'(i0)') nsp_sld+2
        chrfmt = '('//trim(adjustl(chrfmt))//'(1x,a5))'
        write(isldprof,trim(adjustl(chrfmt))) 'z',(chrsld(isps),isps=1,nsp_sld),'time'
        write(isldprof2,trim(adjustl(chrfmt))) 'z',(chrsld(isps),isps=1,nsp_sld),'time'
        write(isldprof3,trim(adjustl(chrfmt))) 'z',(chrsld(isps),isps=1,nsp_sld),'time'
        write(isldsat,trim(adjustl(chrfmt))) 'z',(chrsld(isps),isps=1,nsp_sld),'time'
        write(chrfmt,'(i0)') nsp_aq+3
        chrfmt = '('//trim(adjustl(chrfmt))//'(1x,a5))'
        write(iaqprof,trim(adjustl(chrfmt))) 'z',(chraq(isps),isps=1,nsp_aq),'ph','time'
        write(chrfmt,'(i0)') nsp_gas+2
        chrfmt = '('//trim(adjustl(chrfmt))//'(1x,a5))'
        write(igasprof,trim(adjustl(chrfmt))) 'z',(chrgas(isps),isps=1,nsp_gas),'time'
        write(chrfmt,'(i0)') 10
        chrfmt = '('//trim(adjustl(chrfmt))//'(1x,a11))'
        write(ibsd,trim(adjustl(chrfmt))) 'z','poro', 'sat', 'v[m/yr]', 'm2/m3' , 'w[m/yr]' &
            & , 'vol[m3/m3]','dens[g/cm3]','blk[wt%]','time'
        write(chrfmt,'(i0)') 2 + nsp_sld + nrxn_ext
        chrfmt = '('//trim(adjustl(chrfmt))//'(1x,a5))'
        write(irate,trim(adjustl(chrfmt))) 'z',(chrsld(isps),isps=1,nsp_sld),(chrrxn_ext(irxn),irxn=1,nrxn_ext),'time'

        do iz = 1, Nz
            ucvsld1 = 1d0
            if (msldunit == 'blk') ucvsld1 = 1d0 - poro(iz)
            
            write(isldprof,*) z(iz),(msldx(isps,iz),isps = 1, nsp_sld),time
            write(isldprof2,*) z(iz),(msldx(isps,iz)*mwt(isps)*1d2/ucvsld1/(rho_grain_z(iz)*1d6),isps = 1, nsp_sld),time
            write(isldprof3,*) z(iz),(msldx(isps,iz)*mv(isps)/ucvsld1*1d-6*1d2,isps = 1, nsp_sld),time
            write(isldsat,*) z(iz),(omega(isps,iz),isps = 1, nsp_sld),time
            write(igasprof,*) z(iz),(mgasx(ispg,iz),ispg = 1, nsp_gas),time
            write(iaqprof,*) z(iz),(maqx(ispa,iz),ispa = 1, nsp_aq),-log10(prox(iz)),time
            write(ibsd,*) z(iz), poro(iz),sat(iz),v(iz),hr(iz),w(iz),sldvolfrac(iz),rho_grain_z(iz)  &
                & ,mblkx(iz)*mwtblk*1d2/ucvsld1/(rho_grain_z(iz)*1d6),time
            write(irate,*) z(iz), (rxnsld(isps,iz),isps=1,nsp_sld),(rxnext(irxn,iz),irxn=1,nrxn_ext), time 
        end do

        close(isldprof)
        close(isldprof2)
        close(isldprof3)
        close(isldsat)
        close(iaqprof)
        close(igasprof)
        close(ibsd)
        close(irate)
        
        if (do_psd) then 
            
            open(ipsd, file=trim(adjustl(profdir))//'/'  &
                & //'psd-'//chr//'.txt', status='replace')
            open(ipsdv, file=trim(adjustl(profdir))//'/'  &
                & //'psd(v%)-'//chr//'.txt', status='replace')
            open(ipsds, file=trim(adjustl(profdir))//'/'  &
                & //'psd(SA%)-'//chr//'.txt', status='replace')
            open(ipsdflx, file=trim(adjustl(flxdir))//'/'  &
                & //'flx_psd-'//chr//'.txt', status='replace')
            
            write(chrfmt,'(i0)') nps
            chrfmt = '(1x,a16,'//trim(adjustl(chrfmt))//'(1x,f11.6),1x,a5)'
            write(ipsd,trim(adjustl(chrfmt))) 'z[m]\log10(r[m])',(ps(ips),ips=1,nps),'time'
            write(ipsdv,trim(adjustl(chrfmt))) 'z[m]\log10(r[m])',(ps(ips),ips=1,nps),'time'
            write(ipsds,trim(adjustl(chrfmt))) 'z[m]\log10(r[m])',(ps(ips),ips=1,nps),'time'
            write(chrfmt,'(i0)') nflx_psd
            chrfmt = '(1x,a5,1x,a16,'//trim(adjustl(chrfmt))//'(1x,a11))'
            write(ipsdflx,trim(adjustl(chrfmt))) 'time','log10(r[m])\flx','tflx','adv','dif','rain','rxn','res'
            
            do iz = 1, Nz
                ucvsld2 = 1d0 - poro(iz)
                if (msldunit == 'blk') ucvsld2 = 1d0
                
                write(ipsd,*) z(iz), (psd(ips,iz),ips=1,nps), time 
                write(ipsdv,*) z(iz), (4d0/3d0*pi*(10d0**ps(ips))**3d0*psd(ips,iz)*dps(ips) &
                    ! & /sum( 4d0/3d0*pi*(10d0**ps(:))**3d0*psd(:,iz)*dps(:))  * 1d2 &
                    & / ( sum( msld(:,iz)*mv(:)*1d-6) + mblk(iz)*mvblk*1d-6 ) * 1d2 &
                    & /ucvsld2  &
                    & ,ips=1,nps), time 
                if (.not.incld_rough) then 
                    write(ipsds,*) z(iz), (4d0*pi*(10d0**ps(ips))**2d0*psd(ips,iz)*dps(ips) &
                        ! & /sum( 4d0*pi*(10d0**ps(:))**2d0*psd(:,iz)*dps(:))  * 1d2 &
                        & / ssa(iz)  * 1d2 &
                        ! & /( poro(iz)/(1d0 - poro(iz) ))  &
                        & ,ips=1,nps), time 
                else
                    write(ipsds,*) z(iz), (4d0*pi*(10d0**ps(ips))**2d0*rough_c0*(10d0**ps(ips))**rough_c1*psd(ips,iz)*dps(ips) &
                        ! & /sum( 4d0*pi*(10d0**ps(:))**2d0*rough_c0*(10d0**ps(:))**rough_c1*psd(:,iz)*dps(:))  * 1d2 &
                        & / ssa(iz)  * 1d2 &
                        ! & /( poro(iz)/(1d0 - poro(iz) ))  &
                        & ,ips=1,nps), time 
                endif 
            end do
            
            do ips=1,nps
                write(ipsdflx,*) time,ps(ips), (sum(flx_psd(ips,iflx,:)*dz(:)),iflx=1,nflx_psd)
            enddo 
            
            close(ipsd)
            close(ipsdv)
            close(ipsds)
            close(ipsdflx)
        
        endif 
        
        irec=irec+1
        
#ifdef full_flux_report
        do isps=1,nsp_sld 
            do iz=1,nz
                write(chriz,'(i3.3)') iz
                open(isldflx(isps,iz), file=trim(adjustl(flxdir))//'/' &
                    & //'flx_sld-'//trim(adjustl(chrsld(isps)))//'-'//trim(adjustl(chriz))//'.txt' &
                    & , action='write',status='old',position='append')
                write(isldflx(isps,iz),*) time,z(iz),(sum(flx_sld(isps,iflx,1:iz)*dz(1:iz)),iflx=1,nflx)
                close(isldflx(isps,iz))
            enddo 
        enddo 
        
        do ispa=1,nsp_aq 
            do iz= 1,nz
                write(chriz,'(i3.3)') iz
                open(iaqflx(ispa,iz), file=trim(adjustl(flxdir))//'/' &
                    & //'flx_aq-'//trim(adjustl(chraq(ispa)))//'-'//trim(adjustl(chriz))//'.txt' &
                    & , action='write',status='old',position='append')
                write(iaqflx(ispa,iz),*) time,z(iz),(sum(flx_aq(ispa,iflx,1:iz)*dz(1:iz)),iflx=1,nflx)
                close(iaqflx(ispa,iz))
            enddo 
        enddo 
        
        do ispg=1,nsp_gas 
            do iz=1,nz
                write(chriz,'(i3.3)') iz
                open(igasflx(ispg,iz), file=trim(adjustl(flxdir))//'/' &
                    & //'flx_gas-'//trim(adjustl(chrgas(ispg)))//'-'//trim(adjustl(chriz))//'.txt'  &
                    & , action='write',status='old',position='append')
                write(igasflx(ispg,iz),*) time,z(iz),(sum(flx_gas(ispg,iflx,1:iz)*dz(1:iz)),iflx=1,nflx)
                close(igasflx(ispg,iz))
            enddo 
        enddo 
        
        do ico2=1,6 
            do iz=1,nz
                write(chriz,'(i3.3)') iz
                open(ico2flx(ico2,iz), file=trim(adjustl(flxdir))//'/' &
                    & //'flx_co2sp-'//trim(adjustl(chrco2sp(ico2)))//'-'//trim(adjustl(chriz))//'.txt' &
                    & , action='write',status='old',position='append')
                if (ico2 .le. 4) then 
                    write(ico2flx(ico2,iz),*) time,z(iz),(sum(flx_co2sp(ico2,iflx,1:iz)*dz(1:iz)),iflx=1,nflx)
                elseif (ico2 .eq. 5) then 
                    write(ico2flx(ico2,iz),*) time,z(iz) &
                        & ,(sum(flx_co2sp(2,iflx,1:iz)*dz(1:iz))+sum(flx_co2sp(3,iflx,1:iz)*dz(1:iz)) &
                        &       +sum(flx_co2sp(4,iflx,1:iz)*dz(1:iz)) &
                        & ,iflx=1,nflx)
                elseif (ico2 .eq. 6) then 
                    write(ico2flx(ico2,iz),*) time,z(iz) &
                        & ,(sum(flx_co2sp(3,iflx,1:iz)*dz(1:iz))+2d0*sum(flx_co2sp(4,iflx,1:iz)*dz(1:iz)) &
                        & ,iflx=1,nflx)
                endif 
                close(ico2flx(ico2,iz))
            enddo 
        enddo 
#else
        do isps=1,nsp_sld 
            open(isldflx(isps), file=trim(adjustl(flxdir))//'/' &
                & //'flx_sld-'//trim(adjustl(chrsld(isps)))//'.txt', action='write',status='old',position='append')
            write(isldflx(isps),*) time,(sum(flx_sld(isps,iflx,:)*dz(:)),iflx=1,nflx)
            close(isldflx(isps))
        enddo 
        
        do ispa=1,nsp_aq 
            open(iaqflx(ispa), file=trim(adjustl(flxdir))//'/' &
                & //'flx_aq-'//trim(adjustl(chraq(ispa)))//'.txt', action='write',status='old',position='append')
            write(iaqflx(ispa),*) time,(sum(flx_aq(ispa,iflx,:)*dz(:)),iflx=1,nflx)
            close(iaqflx(ispa))
        enddo 
        
        do ispg=1,nsp_gas 
            open(igasflx(ispg), file=trim(adjustl(flxdir))//'/' &
                & //'flx_gas-'//trim(adjustl(chrgas(ispg)))//'.txt', action='write',status='old',position='append')
            write(igasflx(ispg),*) time,(sum(flx_gas(ispg,iflx,:)*dz(:)),iflx=1,nflx)
            close(igasflx(ispg))
        enddo 
        
        do ico2=1,6 
            open(ico2flx(ico2), file=trim(adjustl(flxdir))//'/' &
                & //'flx_co2sp-'//trim(adjustl(chrco2sp(ico2)))//'.txt', action='write',status='old',position='append')
            if (ico2 .le. 4) then 
                write(ico2flx(ico2),*) time,(sum(flx_co2sp(ico2,iflx,:)*dz(:)),iflx=1,nflx)
            elseif (ico2 .eq. 5) then 
                write(ico2flx(ico2),*) time &
                    & ,(sum(flx_co2sp(2,iflx,:)*dz(:))+sum(flx_co2sp(3,iflx,:)*dz(:))+sum(flx_co2sp(4,iflx,:)*dz(:)) &
                    & ,iflx=1,nflx)
            elseif (ico2 .eq. 6) then 
                write(ico2flx(ico2),*) time &
                    & ,(sum(flx_co2sp(3,iflx,:)*dz(:))+2d0*sum(flx_co2sp(4,iflx,:)*dz(:)) &
                    & ,iflx=1,nflx)
            endif 
            close(ico2flx(ico2))
        enddo 
#endif 
        
        open(isldprof,file=trim(adjustl(profdir))//'/' &
            & //'prof_sld-save.txt', status='replace')
        open(igasprof,file=trim(adjustl(profdir))//'/' &
            & //'prof_gas-save.txt', status='replace')
        open(iaqprof,file=trim(adjustl(profdir))//'/' &
            & //'prof_aq-save.txt', status='replace')
        open(ibsd, file=trim(adjustl(profdir))//'/'  &
            & //'bsd-save.txt', status='replace')
        open(ipsd, file=trim(adjustl(profdir))//'/'  &
            & //'psd-save.txt', status='replace')
            
        write(isldprof,*) ' z ',(chrsld(isps),isps=1,nsp_sld),' time '
        write(iaqprof,*) ' z ',(chraq(isps),isps=1,nsp_aq),' ph ',' time '
        write(igasprof,*) ' z ',(chrgas(isps),isps=1,nsp_gas),' time '
        write(ibsd,*) ' z ',' poro ', ' sat ', ' v[m/yr] ', ' m2/m3 ' ,' w[m/yr] '  &
            & , ' vol[m3/m3] ',' dens[g/cm3] ', ' blk[wt%] ', ' time '
        write(ipsd,*) ' z[m]\log10(r[m]) ',(ps(ips),ips=1,nps),' time '

        do iz = 1, Nz
            ucvsld1 = 1d0
            if (msldunit == 'blk') ucvsld1 = 1d0 - poro(iz)
            write(isldprof,*) z(iz),(msldx(isps,iz),isps = 1, nsp_sld),time
            write(igasprof,*) z(iz),(mgasx(isps,iz),isps = 1, nsp_gas),time
            write(iaqprof,*) z(iz),(maqx(isps,iz),isps = 1, nsp_aq),-log10(prox(iz)),time
            write(ibsd,*) z(iz), poro(iz),sat(iz),v(iz),hr(iz),w(iz),sldvolfrac(iz),rho_grain_z(iz) &
                & ,mblkx(iz)*mwtblk*1d2/ucvsld1/(rho_grain_z(iz)*1d6),time
            write(ipsd,*) z(iz), (psd(ips,iz),ips=1,nps), time 
        end do

        close(isldprof)
        close(iaqprof)
        close(igasprof)
        close(ibsd)
        close(ipsd)
        
! #ifdef disp_lim
        if (display_lim_in) display_lim = .false.
! #endif 
        
    end if
    
    ! saving flx when climate is changed within model 
    if (any(climate) .and. any (ict_change)) then 
        do isps=1,nsp_sld 
            open(isldflx(isps), file=trim(adjustl(flxdir))//'/' &
                & //'flx_sld-'//trim(adjustl(chrsld(isps)))//'.txt', action='write',status='old',position='append')
            write(isldflx(isps),*) time,(sum(flx_sld(isps,iflx,:)*dz(:)),iflx=1,nflx)
            close(isldflx(isps))
        enddo 
        
        do ispa=1,nsp_aq 
            open(iaqflx(ispa), file=trim(adjustl(flxdir))//'/' &
                & //'flx_aq-'//trim(adjustl(chraq(ispa)))//'.txt', action='write',status='old',position='append')
            write(iaqflx(ispa),*) time,(sum(flx_aq(ispa,iflx,:)*dz(:)),iflx=1,nflx)
            close(iaqflx(ispa))
        enddo 
        
        do ispg=1,nsp_gas 
            open(igasflx(ispg), file=trim(adjustl(flxdir))//'/' &
                & //'flx_gas-'//trim(adjustl(chrgas(ispg)))//'.txt', action='write',status='old',position='append')
            write(igasflx(ispg),*) time,(sum(flx_gas(ispg,iflx,:)*dz(:)),iflx=1,nflx)
            close(igasflx(ispg))
        enddo 
        
        do ico2=1,6 
            open(ico2flx(ico2), file=trim(adjustl(flxdir))//'/' &
                & //'flx_co2sp-'//trim(adjustl(chrco2sp(ico2)))//'.txt', action='write',status='old',position='append')
            if (ico2 .le. 4) then 
                write(ico2flx(ico2),*) time,(sum(flx_co2sp(ico2,iflx,:)*dz(:)),iflx=1,nflx)
            elseif (ico2 .eq. 5) then 
                write(ico2flx(ico2),*) time &
                    & ,(sum(flx_co2sp(2,iflx,:)*dz(:))+sum(flx_co2sp(3,iflx,:)*dz(:))+sum(flx_co2sp(4,iflx,:)*dz(:)) &
                    & ,iflx=1,nflx)
            elseif (ico2 .eq. 6) then 
                write(ico2flx(ico2),*) time &
                    & ,(sum(flx_co2sp(3,iflx,:)*dz(:))+2d0*sum(flx_co2sp(4,iflx,:)*dz(:)) &
                    & ,iflx=1,nflx)
            endif 
            close(ico2flx(ico2))
        enddo 
    endif 

    it = it + 1
    time = time + dt
    count_dtunchanged = count_dtunchanged + 1
    
    progress_rate_prev = progress_rate
    
    ! call cpu_time(time_fin)
    call system_clock(t2,t_rate,t_max)
    if ( t2 < t1 ) then
        diff = (t_max - t1) + t2 + 1
    else
        diff = t2 - t1
    endif
    
    ! progress_rate = dt/(time_fin-time_start)*sec2yr ! (model yr)/(computer yr)
    ! progress_rate = (time_fin-time_start) ! (computer sec)
    progress_rate = diff/dble(t_rate) ! (computer sec)
    
    if (.not.timestep_fixed) then 
        if (it/=1) then 
            if (flgreducedt) then 
                maxdt = maxdt/10d0
                flgreducedt = .false.
                count_dtunchanged = 0
            else
                ! maxdt = maxdt* (progress_rate/progress_rate_prev)**0.33d0
                maxdt = maxdt* (progress_rate/progress_rate_prev)**(-0.33d0)
                if (maxdt > maxdt_max) maxdt = maxdt_max
                if (dt < maxdt) count_dtunchanged = 0
                ! if (dt > maxdt) dt = maxdt
            endif 
            
            if (count_dtunchanged > count_dtunchanged_Max) then 
                maxdt = maxdt*10d0
                count_dtunchanged = 0
            endif 
        endif 
    endif 
    
    ! if (progress_rate ==0d0 .or. progress_rate_prev ==0d0) maxdt = 1d2
    ! print *,progress_rate,progress_rate_prev,maxdt,time_fin,time_start
    if (isnan(maxdt).or.maxdt ==0d0) then 
    ! if (.true.) then 
        print *
        print *, 'maxdt is nan or zero',progress_rate,progress_rate_prev,maxdt,time_fin,time_start
        stop
    endif 
    
    if (display  .and. (.not. display_lim)) then 
        print *
        print '(E11.3,a)',progress_rate,': computation time per iteration [sec]'
        print '(E11.3,a)',maxdt, ': maxdt [yr]'
        print '(i11,a)',count_dtunchanged,': count_dtunchanged'
        print *, '-----------------------------------------'
        print *
    endif 
    
end do
        
        
open(isldprof,file=trim(adjustl(profdir))//'/' &
    & //'prof_sld-save.txt', status='replace')
open(igasprof,file=trim(adjustl(profdir))//'/' &
    & //'prof_gas-save.txt', status='replace')
open(iaqprof,file=trim(adjustl(profdir))//'/' &
    & //'prof_aq-save.txt', status='replace')
open(ibsd, file=trim(adjustl(profdir))//'/'  &
    & //'bsd-save.txt', status='replace')
open(ipsd, file=trim(adjustl(profdir))//'/'  &
    & //'psd-save.txt', status='replace')
            
write(isldprof,*) ' z ',(chrsld(isps),isps=1,nsp_sld),' time '
write(iaqprof,*) ' z ',(chraq(isps),isps=1,nsp_aq),' ph ',' time '
write(igasprof,*) ' z ',(chrgas(isps),isps=1,nsp_gas),' time '
write(ibsd,*) ' z ',' poro ', ' sat ', ' v[m/yr] ', ' m2/m3 ' ,' w[m/yr] ' &
    & , ' vol[m3/m3] ',' dens[g/cm3] ', ' blk[wt%] ',' time '
write(ipsd,*) ' z[m]\log10(r[m]) ',(ps(ips),ips=1,nps),' time '

do iz = 1, Nz
    ucvsld1 = 1d0
    if (msldunit == 'blk') ucvsld1 = 1d0 - poro(iz)
    write(isldprof,*) z(iz),(msldx(isps,iz),isps = 1, nsp_sld),time
    write(igasprof,*) z(iz),(mgasx(isps,iz),isps = 1, nsp_gas),time
    write(iaqprof,*) z(iz),(maqx(isps,iz),isps = 1, nsp_aq),-log10(prox(iz)),time
    write(ibsd,*) z(iz), poro(iz),sat(iz),v(iz),hr(iz),w(iz),sldvolfrac(iz),rho_grain_z(iz)  &
        & ,mblkx(iz)*mwtblk*1d2/ucvsld1/(rho_grain_z(iz)*1d6),time
    write(ipsd,*) z(iz), (psd(ips,iz),ips=1,nps), time 
end do

close(isldprof)
close(iaqprof)
close(igasprof)
close(ibsd)
close(ipsd)

call system ('cp gases.in '//trim(adjustl(profdir))//'/gases.save')
call system ('cp solutes.in '//trim(adjustl(profdir))//'/solutes.save')
call system ('cp slds.in '//trim(adjustl(profdir))//'/slds.save')
call system ('cp extrxns.in '//trim(adjustl(profdir))//'/extrxns.save')
call system ('cp kinspc.in '//trim(adjustl(profdir))//'/kinspc.save')

endsubroutine weathering_main

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine get_clim_num( &
    & file_in &! in 
    & ,n_file &! output
    & )
implicit none

character(50),intent(in)::file_in
integer,intent(out):: n_file
character(500) file_name

file_name = './'//trim(adjustl(file_in)) 
call Console4(file_name,n_file)

n_file = n_file - 1

endsubroutine get_clim_num

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine get_variables_num( &
    & nsp_aq,nsp_sld,nsp_gas,nrxn_ext,nsld_kinspc &! output
    & )
implicit none

integer,intent(out):: nsp_sld,nsp_aq,nsp_gas,nrxn_ext,nsld_kinspc
character(500) file_name

file_name = './slds.in'
call Console4(file_name,nsp_sld)
file_name = './solutes.in'
call Console4(file_name,nsp_aq)
file_name = './gases.in'
call Console4(file_name,nsp_gas)
file_name = './extrxns.in'
call Console4(file_name,nrxn_ext)
file_name = './kinspc.in'
call Console4(file_name,nsld_kinspc)

nsp_sld = nsp_sld - 1
nsp_aq = nsp_aq - 1
nsp_gas = nsp_gas - 1
nrxn_ext = nrxn_ext - 1
nsld_kinspc = nsld_kinspc - 1

endsubroutine get_variables_num

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine get_variables( &
    & nsp_aq,nsp_sld,nsp_gas,nrxn_ext,nsld_kinspc &! input
    & ,chraq,chrgas,chrsld,chrrxn_ext,chrsld_kinspc,kin_sld_spc &! output
    & )
implicit none

integer,intent(in):: nsp_sld,nsp_aq,nsp_gas,nrxn_ext,nsld_kinspc
character(5),dimension(nsp_sld),intent(out)::chrsld 
character(5),dimension(nsp_aq),intent(out)::chraq 
character(5),dimension(nsp_gas),intent(out)::chrgas 
character(5),dimension(nrxn_ext),intent(out)::chrrxn_ext 
character(5),dimension(nsld_kinspc),intent(out)::chrsld_kinspc
real(kind=8),dimension(nsld_kinspc),intent(out)::kin_sld_spc

character(500) file_name
integer ispa,ispg,isps,irxn,isldspc

if (nsp_aq>=1) then 
    file_name = './solutes.in'
    open(50,file=trim(adjustl(file_name)),status = 'old',action='read')
    read(50,'()')
    do ispa =1,nsp_aq
        read(50,*) chraq(ispa) 
    enddo 
    close(50)
endif 

if (nsp_sld>=1) then 
    file_name = './slds.in'
    open(50,file=trim(adjustl(file_name)),status = 'old',action='read')
    read(50,'()')
    do isps =1,nsp_sld
        read(50,*) chrsld(isps) 
    enddo  
    close(50)
endif 

if (nsp_gas>=1) then 
    file_name = './gases.in'
    open(50,file=trim(adjustl(file_name)),status = 'old',action='read')
    read(50,'()')
    do ispg =1,nsp_gas
        read(50,*) chrgas(ispg) 
    enddo 
    close(50)
endif 

if (nrxn_ext>=1) then 
    file_name = './extrxns.in'
    open(50,file=trim(adjustl(file_name)),status = 'old',action='read')
    read(50,'()')
    do irxn =1,nrxn_ext
        read(50,*) chrrxn_ext(irxn) 
    enddo 
    close(50)
endif 

if (nsld_kinspc>=1) then 
    file_name = './kinspc.in'
    open(50,file=trim(adjustl(file_name)),status = 'old',action='read')
    read(50,'()')
    do isldspc =1,nsld_kinspc
        read(50,*) chrsld_kinspc(isldspc), kin_sld_spc(isldspc) 
    enddo 
    close(50)
endif 

endsubroutine get_variables

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine get_saved_variables_num( &
    & workdir,runname_save &! input 
    & ,nsp_aq,nsp_sld,nsp_gas,nrxn_ext,nsld_kinspc &! output
    & )
implicit none

integer,intent(out):: nsp_sld,nsp_aq,nsp_gas,nrxn_ext,nsld_kinspc
character(256),intent(in):: workdir,runname_save
character(500) file_name

file_name = trim(adjustl(workdir))//trim(adjustl(runname_save))//'/slds.save'
call Console4(file_name,nsp_sld)
file_name = trim(adjustl(workdir))//trim(adjustl(runname_save))//'/solutes.save'
call Console4(file_name,nsp_aq)
file_name = trim(adjustl(workdir))//trim(adjustl(runname_save))//'/gases.save'
call Console4(file_name,nsp_gas)
file_name = trim(adjustl(workdir))//trim(adjustl(runname_save))//'/extrxns.save'
call Console4(file_name,nrxn_ext)
file_name = trim(adjustl(workdir))//trim(adjustl(runname_save))//'/kinspc.save'
call Console4(file_name,nsld_kinspc)

nsp_sld = nsp_sld - 1
nsp_aq = nsp_aq - 1
nsp_gas = nsp_gas - 1
nrxn_ext = nrxn_ext - 1
nsld_kinspc = nsld_kinspc - 1

endsubroutine get_saved_variables_num

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine get_saved_variables( &
    & workdir,runname_save &! input 
    & ,nsp_aq,nsp_sld,nsp_gas,nrxn_ext,nsld_kinspc &! input
    & ,chraq,chrgas,chrsld,chrrxn_ext,chrsld_kinspc,kin_sld_spc &! output
    & )
implicit none

integer,intent(in):: nsp_sld,nsp_aq,nsp_gas,nrxn_ext,nsld_kinspc
character(5),dimension(nsp_sld),intent(out)::chrsld 
character(5),dimension(nsp_aq),intent(out)::chraq 
character(5),dimension(nsp_gas),intent(out)::chrgas 
character(5),dimension(nrxn_ext),intent(out)::chrrxn_ext 
character(5),dimension(nsld_kinspc),intent(out)::chrsld_kinspc 
character(256),intent(in):: workdir,runname_save
real(kind=8),dimension(nsld_kinspc),intent(out)::kin_sld_spc

character(500) file_name
integer ispa,ispg,isps,irxn,isldspc

if (nsp_aq>=1) then 
    file_name = trim(adjustl(workdir))//trim(adjustl(runname_save))//'/solutes.save'
    open(50,file=trim(adjustl(file_name)),status = 'old',action='read')
    read(50,'()')
    do ispa =1,nsp_aq
        read(50,*) chraq(ispa) 
    enddo 
    close(50)
endif 

if (nsp_sld>=1) then 
    file_name = trim(adjustl(workdir))//trim(adjustl(runname_save))//'/slds.save'
    open(50,file=trim(adjustl(file_name)),status = 'old',action='read')
    read(50,'()')
    do isps =1,nsp_sld
        read(50,*) chrsld(isps) 
    enddo  
    close(50)
endif 

if (nsp_gas>=1) then 
    file_name = trim(adjustl(workdir))//trim(adjustl(runname_save))//'/gases.save'
    open(50,file=trim(adjustl(file_name)),status = 'old',action='read')
    read(50,'()')
    do ispg =1,nsp_gas
        read(50,*) chrgas(ispg) 
    enddo 
    close(50)
endif 

if (nrxn_ext>=1) then 
    file_name = trim(adjustl(workdir))//trim(adjustl(runname_save))//'/extrxns.save'
    open(50,file=trim(adjustl(file_name)),status = 'old',action='read')
    read(50,'()')
    do irxn =1,nrxn_ext
        read(50,*) chrrxn_ext(irxn) 
    enddo 
    close(50)
endif 

if (nsld_kinspc>=1) then 
    file_name = trim(adjustl(workdir))//trim(adjustl(runname_save))//'/kinspc.save'
    open(50,file=trim(adjustl(file_name)),status = 'old',action='read')
    read(50,'()')
    do isldspc =1,nsld_kinspc
        read(50,*) chrsld_kinspc(isldspc), kin_sld_spc(isldspc) 
    enddo 
    close(50)
endif 

endsubroutine get_saved_variables

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine get_bsdvalues( &
    & nz,ztot,ttot,rainpowder,zsupp,poroi,satup,zsat,zml_ref,w,qin,p80,sim_name,plant_rain,runname_save &! output
    & ,count_dtunchanged_Max,tc &
    & )
implicit none

integer,intent(out):: nz
real(kind=8),intent(out)::ztot,ttot,rainpowder,zsupp,poroi,satup,zsat,w,qin,p80,plant_rain,zml_ref,tc
character(500),intent(out)::sim_name,runname_save
integer,intent(out)::count_dtunchanged_Max

character(500) file_name

file_name = './frame.in'
open(50,file=trim(adjustl(file_name)),status = 'old',action='read')
read(50,'()')
read(50,*) ztot
read(50,*) nz
read(50,*) ttot
read(50,*) tc
read(50,*) rainpowder
read(50,*) plant_rain
read(50,*) zsupp
read(50,*) poroi
read(50,*) satup
read(50,*) zsat
read(50,*) zml_ref
read(50,*) w
read(50,*) qin
read(50,*) p80
read(50,*) count_dtunchanged_Max
read(50,*) runname_save
read(50,'()')
read(50,*) sim_name
close(50)

print*,'nz,ztot,ttot,rainpowder,zsupp,poroi,satup,zsat,w,qin,p80,sim_name,plant_rain,runname_save,count_dtunchanged_Max'
print*,nz,ztot,ttot,rainpowder,zsupp,poroi,satup,zsat,w,qin,p80,sim_name,plant_rain,runname_save,count_dtunchanged_Max

endsubroutine get_bsdvalues

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine get_rainwater( &
    & nsp_aq_all,chraq_all,def_rain &! input
    & ,rain_all &! output
    & )
implicit none

integer,intent(in):: nsp_aq_all
character(5),dimension(nsp_aq_all),intent(in)::chraq_all
real(kind=8),dimension(nsp_aq_all),intent(out)::rain_all
real(kind=8),intent(in)::def_rain 
character(5) chr_tmp
real(kind=8) val_tmp

character(500) file_name
integer i,n_tmp

file_name = './rain.in'
call Console4(file_name,n_tmp)

n_tmp = n_tmp - 1

! in default 
rain_all = def_rain

if (n_tmp <= 0) return

open(50,file=trim(adjustl(file_name)),status = 'old',action='read')
read(50,'()')
do i =1,n_tmp
    read(50,*) chr_tmp,val_tmp
    if (any(chraq_all == chr_tmp)) then 
        rain_all(findloc(chraq_all,chr_tmp,dim=1)) = val_tmp
    endif 
enddo 
close(50)


endsubroutine get_rainwater

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine get_dust( &
    & nsp_sld_all,chrsld_all,def_dust &! input
    & ,dust_frct_all &! output
    & )
implicit none

integer,intent(in):: nsp_sld_all
character(5),dimension(nsp_sld_all),intent(in)::chrsld_all
real(kind=8),dimension(nsp_sld_all),intent(out)::dust_frct_all
real(kind=8),intent(in)::def_dust 
character(5) chr_tmp
real(kind=8) val_tmp

character(500) file_name
integer i,n_tmp

file_name = './dust.in'
call Console4(file_name,n_tmp)

n_tmp = n_tmp - 1

! in default 
dust_frct_all = def_dust

if (n_tmp <= 0) return

open(50,file=trim(adjustl(file_name)),status = 'old',action='read')
read(50,'()')
do i =1,n_tmp
    read(50,*) chr_tmp,val_tmp
    if (any(chrsld_all == chr_tmp)) then 
        dust_frct_all(findloc(chrsld_all,chr_tmp,dim=1)) = val_tmp
    endif 
enddo 
close(50)


endsubroutine get_dust

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine get_OM_rain( &
    & nsp_sld_all,chrsld_all,def_OM_frc &! input
    & ,OM_frct_all &! output
    & )
implicit none

integer,intent(in):: nsp_sld_all
character(5),dimension(nsp_sld_all),intent(in)::chrsld_all
real(kind=8),dimension(nsp_sld_all),intent(out)::OM_frct_all
real(kind=8),intent(in)::def_OM_frc 
character(5) chr_tmp
real(kind=8) val_tmp

character(500) file_name
integer i,n_tmp

file_name = './OM_rain.in'
call Console4(file_name,n_tmp)

n_tmp = n_tmp - 1

! in default 
OM_frct_all = def_OM_frc

if (n_tmp <= 0) return

open(50,file=trim(adjustl(file_name)),status = 'old',action='read')
read(50,'()')
do i =1,n_tmp
    read(50,*) chr_tmp,val_tmp
    if (any(chrsld_all == chr_tmp)) then 
        OM_frct_all(findloc(chrsld_all,chr_tmp,dim=1)) = val_tmp
    endif 
enddo 
close(50)


endsubroutine get_OM_rain

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine get_parentrock( &
    & nsp_sld_all,chrsld_all,def_pr &! input
    & ,parentrock_frct_all &! output
    & )
implicit none

integer,intent(in):: nsp_sld_all
character(5),dimension(nsp_sld_all),intent(in)::chrsld_all
real(kind=8),dimension(nsp_sld_all),intent(out)::parentrock_frct_all
real(kind=8),intent(in)::def_pr 
character(5) chr_tmp
real(kind=8) val_tmp

character(500) file_name
integer i,n_tmp

file_name = './parentrock.in'
call Console4(file_name,n_tmp)

n_tmp = n_tmp - 1

! in default 
parentrock_frct_all = def_pr

if (n_tmp <= 0) return

open(50,file=trim(adjustl(file_name)),status = 'old',action='read')
read(50,'()')
do i =1,n_tmp
    read(50,*) chr_tmp,val_tmp
    if (any(chrsld_all == chr_tmp)) then 
        parentrock_frct_all(findloc(chrsld_all,chr_tmp,dim=1)) = val_tmp
    endif 
enddo 
close(50)


endsubroutine get_parentrock

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine get_atm( &
    & nsp_gas_all,chrgas_all &! input
    & ,atm_all &! output
    & )
implicit none

integer,intent(in):: nsp_gas_all
character(5),dimension(nsp_gas_all),intent(in)::chrgas_all
real(kind=8),dimension(nsp_gas_all),intent(out)::atm_all
character(5) chr_tmp
real(kind=8) val_tmp

character(500) file_name
integer i,n_tmp

file_name = './atm.in'
call Console4(file_name,n_tmp)

n_tmp = n_tmp - 1

! in default 
atm_all(findloc(chrgas_all,'po2',dim=1)) = 0.21d0
atm_all(findloc(chrgas_all,'pco2',dim=1)) = 10d0**(-3.5d0)
atm_all(findloc(chrgas_all,'pnh3',dim=1)) = 1d-9
atm_all(findloc(chrgas_all,'pn2o',dim=1)) = 270d-9

open(50,file=trim(adjustl(file_name)),status = 'old',action='read')
read(50,'()')
do i =1,n_tmp
    read(50,*) chr_tmp,val_tmp
    if (any(chrgas_all == chr_tmp)) then 
        atm_all(findloc(chrgas_all,chr_tmp,dim=1)) = val_tmp
    endif 
enddo 
close(50)


endsubroutine get_atm

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine get_switches( &
    & iwtype,imixtype,poroiter_in,display,display_lim_in,read_data,incld_rough &
    & ,al_inhibit,timestep_fixed,method_precalc,regular_grid,sld_enforce &! inout
    & ,poroevol,surfevol1,surfevol2,do_psd &! inout
    & )
implicit none

character(100) chr_tmp
logical,intent(inout):: poroiter_in,display,display_lim_in,read_data,incld_rough &
    & ,al_inhibit,timestep_fixed,method_precalc,regular_grid,sld_enforce &
    & ,poroevol,surfevol1,surfevol2,do_psd
integer,intent(out) :: imixtype,iwtype

character(500) file_name
integer i,n_tmp

file_name = './switches.in'

open(50,file=trim(adjustl(file_name)),status = 'old',action='read')
read(50,'()')

read(50,*) iwtype,chr_tmp
read(50,*) imixtype,chr_tmp
read(50,*) poroiter_in,chr_tmp
read(50,*) display,chr_tmp
read(50,*) display_lim_in,chr_tmp
read(50,*) read_data,chr_tmp
read(50,*) incld_rough,chr_tmp
read(50,*) al_inhibit,chr_tmp
read(50,*) timestep_fixed,chr_tmp
read(50,*) method_precalc,chr_tmp
read(50,*) regular_grid,chr_tmp
read(50,*) sld_enforce,chr_tmp
read(50,*) poroevol,chr_tmp
read(50,*) surfevol1,chr_tmp
read(50,*) surfevol2,chr_tmp
read(50,*) do_psd,chr_tmp

close(50)


endsubroutine get_switches

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine Console4(file_name,i)

implicit none

integer,intent(out) :: i
character(500),intent(in)::file_name

open(9, file =trim(adjustl(file_name)))

i = 0
do 
    read(9, *, end = 99)
    i = i + 1
end do 

! 99 print *, i
99 continue
close(9)

end subroutine Console4

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine makegrid(beta,nz,ztot,dz,z,regular_grid)  !  making grid, after Hoffmann & Chiang, 2000
implicit none
integer(kind=4),intent(in) :: nz
logical,intent(in)::regular_grid
real(kind=8),intent(in)::beta,ztot
real(kind=8),intent(out)::dz(nz),z(nz)
integer(kind=4) iz

do iz = 1, nz 
    z(iz) = iz*ztot/nz  ! regular grid 
    if (iz==1) then
        dz(iz) = ztot*log((beta+(z(iz)/ztot)**2d0)/(beta-(z(iz)/ztot)**2d0))/log((beta+1d0)/(beta-1d0))
    endif
    if (iz/=1) then 
        dz(iz) = ztot*log((beta+(z(iz)/ztot)**2d0)/(beta-(z(iz)/ztot)**2d0))/log((beta+1d0)/(beta-1d0)) - sum(dz(:iz-1))
    endif
enddo

if (regular_grid) then 
    dz = ztot/nz  ! when implementing regular grid
endif 

do iz=1,nz  ! depth is defined at the middle of individual layers 
    if (iz==1) z(iz)=dz(iz)*0.5d0  
    if (iz/=1) z(iz) = z(iz-1)+dz(iz-1)*0.5d0 + 0.5d0*dz(iz)
enddo

endsubroutine makegrid

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine coefs_v2( &
    & nz,rg,rg2,tc,sec2yr,tempk_0,pro,poro,hr &! input
    & ,nsp_aq_all,nsp_gas_all,nsp_sld_all,nrxn_ext_all &! input
    & ,chraq_all,chrgas_all,chrsld_all,chrrxn_ext_all &! input
    & ,nsp_gas,nsp_gas_cnst,chrgas,chrgas_cnst,mgas,mgasc,mgasth_all,mv_all,staq_all &!input
    & ,ucv,kw,daq_all,dgasa_all,dgasg_all,keqgas_h,keqaq_h,keqaq_c,keqaq_s,keqaq_no3,keqaq_nh3 &! output
    & ,ksld_all,keqsld_all,krxn1_ext_all,krxn2_ext_all &! output
    & ) 
implicit none

integer,intent(in)::nz
real(kind=8),intent(in)::rg,rg2,tc,sec2yr,tempk_0
real(kind=8),dimension(nz),intent(in)::pro,poro,hr
real(kind=8),dimension(nz)::oh,po2,kin,dkin_dmsp
real(kind=8) kho,po2th,mv_tmp,therm,ss_x,ss_y
real(kind=8),intent(out)::ucv,kw

! real(kind=8) k_arrhenius
real(kind=8) :: cal2j = 4.184d0 

integer,intent(in)::nsp_aq_all,nsp_gas_all,nsp_sld_all,nrxn_ext_all
character(5),dimension(nsp_aq_all),intent(in)::chraq_all
real(kind=8),dimension(nsp_aq_all),intent(out)::daq_all
character(5),dimension(nsp_gas_all),intent(in)::chrgas_all
character(5),dimension(nsp_sld_all),intent(in)::chrsld_all
character(5),dimension(nrxn_ext_all),intent(in)::chrrxn_ext_all
real(kind=8),dimension(nsp_gas_all),intent(out)::dgasa_all,dgasg_all
real(kind=8),dimension(nsp_gas_all,3),intent(out)::keqgas_h
real(kind=8),dimension(nsp_aq_all,4),intent(out)::keqaq_h
real(kind=8),dimension(nsp_aq_all,2),intent(out)::keqaq_c
real(kind=8),dimension(nsp_aq_all,2),intent(out)::keqaq_s
real(kind=8),dimension(nsp_aq_all,2),intent(out)::keqaq_no3
real(kind=8),dimension(nsp_aq_all,2),intent(out)::keqaq_nh3
real(kind=8),dimension(nsp_sld_all,nz),intent(out)::ksld_all
real(kind=8),dimension(nsp_sld_all),intent(in)::mv_all
real(kind=8),dimension(nsp_sld_all,nsp_aq_all),intent(in)::staq_all
real(kind=8),dimension(nsp_sld_all),intent(out)::keqsld_all
real(kind=8),dimension(nrxn_ext_all,nz),intent(out)::krxn1_ext_all
real(kind=8),dimension(nrxn_ext_all,nz),intent(out)::krxn2_ext_all

integer,intent(in)::nsp_gas,nsp_gas_cnst
character(5),dimension(nsp_gas),intent(in)::chrgas
character(5),dimension(nsp_gas_cnst),intent(in)::chrgas_cnst
real(kind=8),dimension(nsp_gas,nz),intent(in)::mgas
real(kind=8),dimension(nsp_gas_cnst,nz),intent(in)::mgasc
real(kind=8),dimension(nsp_gas_all),intent(in)::mgasth_all

real(kind=8),dimension(nsp_gas_all,nz)::mgas_loc

integer ieqgas_h0,ieqgas_h1,ieqgas_h2
data ieqgas_h0,ieqgas_h1,ieqgas_h2/1,2,3/

integer ieqaq_h1,ieqaq_h2,ieqaq_h3,ieqaq_h4
data ieqaq_h1,ieqaq_h2,ieqaq_h3,ieqaq_h4/1,2,3,4/

integer ieqaq_co3,ieqaq_hco3
data ieqaq_co3,ieqaq_hco3/1,2/

integer ieqaq_so4,ieqaq_so42
data ieqaq_so4,ieqaq_so42/1,2/

integer ieqaq_no3,ieqaq_no32
data ieqaq_no3,ieqaq_no32/1,2/

integer ieqaq_nh3,ieqaq_nh32
data ieqaq_nh3,ieqaq_nh32/1,2/

integer isps

! real(kind=8)::thon = 1d0
real(kind=8)::thon = -1d100
character(5) mineral

ucv = 1.0d0/(rg2*(tempk_0+tc))

! Aq species diffusion from Li and Gregory 1974 except for Si which is based on Rebreanu et al. 2008
daq_all(findloc(chraq_all,'fe2',dim=1))= k_arrhenius(1.7016d-2    , 15d0+tempk_0, tc+tempk_0, 19.615251d0, rg)
daq_all(findloc(chraq_all,'fe3',dim=1))= k_arrhenius(1.5664d-2    , 15d0+tempk_0, tc+tempk_0, 14.33659d0 , rg)
daq_all(findloc(chraq_all,'so4',dim=1))= k_arrhenius(2.54d-2      , 15d0+tempk_0, tc+tempk_0, 20.67364d0 , rg)
daq_all(findloc(chraq_all,'no3',dim=1))= k_arrhenius(4.6770059d-2 , 15d0+tempk_0, tc+tempk_0, 18.00685d0 , rg)
daq_all(findloc(chraq_all,'na',dim=1)) = k_arrhenius(3.19d-2      , 15d0+tempk_0, tc+tempk_0, 20.58566d0 , rg)
daq_all(findloc(chraq_all,'k',dim=1))  = k_arrhenius(4.8022699d-2 , 15d0+tempk_0, tc+tempk_0, 18.71816d0 , rg)
daq_all(findloc(chraq_all,'mg',dim=1)) = k_arrhenius(1.7218079d-2 , 15d0+tempk_0, tc+tempk_0, 18.51979d0 , rg)
daq_all(findloc(chraq_all,'si',dim=1)) = k_arrhenius(2.682396d-2  , 15d0+tempk_0, tc+tempk_0, 22.71378d0 , rg)
daq_all(findloc(chraq_all,'ca',dim=1)) = k_arrhenius(1.9023312d-2 , 15d0+tempk_0, tc+tempk_0, 20.219661d0, rg)
daq_all(findloc(chraq_all,'al',dim=1)) = k_arrhenius(1.1656226d-2 , 15d0+tempk_0, tc+tempk_0, 21.27788d0 , rg)

! values used in Kanzaki and Murakami 2016 for oxygen 
dgasa_all(findloc(chrgas_all,'po2',dim=1)) = k_arrhenius(5.49d-2 , 15d0+tempk_0, tc+tempk_0, 20.07d0 , rg)
dgasg_all(findloc(chrgas_all,'po2',dim=1)) = k_arrhenius(6.09d2  , 15d0+tempk_0, tc+tempk_0, 4.18d0  , rg)

! assuming a value of 0.14 cm2/sec (e.g., Pritchard and Currie, 1982) and O2 gas activation energy for CO2 gas 
! and CO32- diffusion from Li and Greogy 1974 for aq CO2 
dgasa_all(findloc(chrgas_all,'pco2',dim=1)) = k_arrhenius(2.2459852d-2, 15d0+tempk_0, tc+tempk_0, 21.00564d0, rg)
dgasg_all(findloc(chrgas_all,'pco2',dim=1)) = k_arrhenius(441.504d0   , 15d0+tempk_0, tc+tempk_0, 4.18d0    , rg)

! NH4+ diffusion for aqueous diffusion from Schulz and Zabel 2005
! NH3 diffusion in air from Massman 1998
dgasa_all(findloc(chrgas_all,'pnh3',dim=1)) = k_arrhenius(4.64d-02    , 15d0+tempk_0, tc+tempk_0, 19.15308d0, rg)
dgasg_all(findloc(chrgas_all,'pnh3',dim=1)) = 0.1978d0*((tc+tempk_0)/(0d0+tempk_0))**1.81d0 * sec2yr *1d-4 ! sec2yr*1d-4 converting cm2 to m2 and sec-1 to yr-1

! assuming the same diffusion as CO2 diffusion (e.g., Pritchard and Currie, 1982) for gaseous N2O 
! N2O(aq) diffusion from Schulz and Zabel 2005
dgasa_all(findloc(chrgas_all,'pn2o',dim=1)) = k_arrhenius(4.89d-02    , 15d0+tempk_0, tc+tempk_0, 20.33417d0, rg)
dgasg_all(findloc(chrgas_all,'pn2o',dim=1)) = k_arrhenius(441.504d0   , 15d0+tempk_0, tc+tempk_0, 4.18d0    , rg)

kw = -14.93d0+0.04188d0*tc-0.0001974d0*tc**2d0+0.000000555d0*tc**3d0-0.0000000007581d0*tc**4d0  ! Murakami et al. 2011
kw = k_arrhenius(10d0**(-14.35d0), tempk_0+15.0d0, tempk_0+tc, 58.736742d0, rg) ! from Kanzaki and Murakami 2015

oh = kw/pro


keqgas_h = 0d0

! kho = k_arrhenius(10.0d0**(-2.89d0), tempk_0+25.0d0, tempk_0+tc, -13.2d0, rg)
keqgas_h(findloc(chrgas_all,'po2',dim=1),ieqgas_h0) = &
    & k_arrhenius(10d0**(-2.89d0), tempk_0+25.0d0, tempk_0+tc, -13.2d0, rg)
kho = keqgas_h(findloc(chrgas_all,'po2',dim=1),ieqgas_h0)

keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h0) = &
    & k_arrhenius(10d0**(-1.34d0), tempk_0+15.0d0, tempk_0+tc, -21.33183d0, rg) ! from Kanzaki and Murakami 2015
keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h1) = &
    & k_arrhenius(10d0**(-6.42d0), tempk_0+15.0d0, tempk_0+tc, 11.94453d0, rg) ! from Kanzaki and Murakami 2015
keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h2) = &
    & k_arrhenius(10d0**(-10.43d0), tempk_0+15.0d0, tempk_0+tc, 17.00089d0, rg) ! from Kanzaki and Murakami 2015

keqgas_h(findloc(chrgas_all,'pnh3',dim=1),ieqgas_h0) = &
    & k_arrhenius(10d0**(1.770d0), tempk_0+25.0d0, tempk_0+tc, -8.170d0*cal2j, rg) ! from WATEQ4F.DAT 
keqgas_h(findloc(chrgas_all,'pnh3',dim=1),ieqgas_h1) = &
    & k_arrhenius(10d0**(-9.252d0), tempk_0+25.0d0, tempk_0+tc, 12.48d0*cal2j, rg) ! from WATEQ4F.DAT (NH4+ = NH3 + H+)

keqgas_h(findloc(chrgas_all,'pn2o',dim=1),ieqgas_h0) = &
    & k_arrhenius(0.033928709d0, tempk_0+15.0d0, tempk_0+tc, -22.21661d0, rg) ! ! N2O solubility from Weiss & Price 1980 MC assuming 0 salinity

    
keqaq_c = 0d0
keqaq_h = 0d0
keqaq_s = 0d0
keqaq_no3 = 0d0
keqaq_nh3 = 0d0

! SO4-2 + H+ = HSO4- 
! keqaq_s(findloc(chraq_all,'so4',dim=1),ieqaq_so4) = &
    ! & k_arrhenius(10d0**(1.988d0),25d0+tempk_0,tc+tempk_0,3.85d0*cal2j,rg) ! from PHREEQC.DAT
keqaq_h(findloc(chraq_all,'so4',dim=1),ieqaq_h1) = &
    & k_arrhenius(10d0**(1.988d0),25d0+tempk_0,tc+tempk_0,3.85d0*cal2j,rg) ! from PHREEQC.DAT
! SO4-2 + NH4+ = NH4SO4-
! keqaq_nh3(findloc(chraq_all,'so4',dim=1),ieqaq_nh3) = &
    ! & k_arrhenius(10d0**(1.03d0),25d0+tempk_0,tc+tempk_0,0d0,rg) ! from MINTEQV4.DAT 

! H+ + NO3- = HNO3 
! keqaq_no3(findloc(chraq_all,'no3',dim=1),ieqaq_no3) = 1d0/35.5d0 ! from Levanov et al. 2017 
! keqaq_no3(findloc(chraq_all,'no3',dim=1),ieqaq_no3) = 1d0/(10d0**1.3d0) ! from Maggi et al. 2007 
keqaq_h(findloc(chraq_all,'no3',dim=1),ieqaq_h1) = 1d0/35.5d0 ! from Levanov et al. 2017 
keqaq_h(findloc(chraq_all,'no3',dim=1),ieqaq_h1) = 1d0/(10d0**1.3d0) ! from Maggi et al. 2007 
! (temperature dependence is assumed to be 0) 

! Al3+ + H2O = Al(OH)2+ + H+
keqaq_h(findloc(chraq_all,'al',dim=1),ieqaq_h1) = &
    & k_arrhenius(10d0**(-5d0),25d0+tempk_0,tc+tempk_0,11.49d0*cal2j,rg) ! from PHREEQC.DAT 
! Al3+ + 2H2O = Al(OH)2+ + 2H+
keqaq_h(findloc(chraq_all,'al',dim=1),ieqaq_h2) = &
    & k_arrhenius(10d0**(-10.1d0),25d0+tempk_0,tc+tempk_0,26.90d0*cal2j,rg) ! from PHREEQC.DAT 
! Al3+ + 3H2O = Al(OH)3 + 3H+
keqaq_h(findloc(chraq_all,'al',dim=1),ieqaq_h3) = &
    & k_arrhenius(10d0**(-16.9d0),25d0+tempk_0,tc+tempk_0,39.89d0*cal2j,rg) ! from PHREEQC.DAT 
! Al3+ + 4H2O = Al(OH)4- + 4H+
keqaq_h(findloc(chraq_all,'al',dim=1),ieqaq_h4) = &
    & k_arrhenius(10d0**(-22.7d0),25d0+tempk_0,tc+tempk_0,42.30d0*cal2j,rg) ! from PHREEQC.DAT 
! Al+3 + SO4-2 = AlSO4+
keqaq_s(findloc(chraq_all,'al',dim=1),ieqaq_so4) = &
    & k_arrhenius(10d0**(3.5d0),25d0+tempk_0,tc+tempk_0,2.29d0*cal2j,rg) ! from PHREEQC.DAT 
! Al+3 + 2SO4-2 = Al(SO4)2-
! ignoring for now
! keqaq_s(findloc(chraq_all,'al',dim=1),ieqaq_so42) = &
    ! & k_arrhenius(10d0**(5.0d0),25d0+tempk_0,tc+tempk_0,3.11d0*cal2j,rg) ! from PHREEQC.DAT 

! H4SiO4 = H3SiO4- + H+
keqaq_h(findloc(chraq_all,'si',dim=1),ieqaq_h1) = &
    & k_arrhenius(10d0**(-9.83d0),25d0+tempk_0,tc+tempk_0,6.12d0*cal2j,rg) ! from PHREEQC.DAT 
! H4SiO4 = H2SiO4-2 + 2 H+
keqaq_h(findloc(chraq_all,'si',dim=1),ieqaq_h2) = &
    & k_arrhenius(10d0**(-23d0),25d0+tempk_0,tc+tempk_0,17.6d0*cal2j,rg) ! from PHREEQC.DAT 


! Mg2+ + H2O = Mg(OH)+ + H+
keqaq_h(findloc(chraq_all,'mg',dim=1),ieqaq_h1) = &
    & k_arrhenius(10d0**(-11.44d0),25d0+tempk_0,tc+tempk_0,15.952d0*cal2j,rg) ! from PHREEQC.DAT 
! Mg2+ + CO32- = MgCO3 
keqaq_c(findloc(chraq_all,'mg',dim=1),ieqaq_co3) = &
    & k_arrhenius(10d0**(2.98d0),25d0+tempk_0,tc+tempk_0,2.713d0*cal2j,rg) ! from PHREEQC.DAT 
! Mg2+ + H+ + CO32- = MgHCO3
keqaq_c(findloc(chraq_all,'mg',dim=1),ieqaq_hco3) = & 
    & k_arrhenius(10d0**(11.399d0),25d0+tempk_0,tc+tempk_0,-2.771d0*cal2j,rg) ! from PHREEQC.DAT 
! Mg+2 + SO4-2 = MgSO4
keqaq_s(findloc(chraq_all,'mg',dim=1),ieqaq_so4) = & 
    & k_arrhenius(10d0**(2.37d0),25d0+tempk_0,tc+tempk_0, 4.550d0*cal2j,rg) ! from PHREEQC.DAT 

! Ca2+ + H2O = Ca(OH)+ + H+
keqaq_h(findloc(chraq_all,'ca',dim=1),ieqaq_h1) =  &
    & k_arrhenius(10d0**(-12.78d0),25d0+tempk_0,tc+tempk_0,15.952d0*cal2j,rg) ! from PHREEQC.DAT 
! (No delta_h is reported so used the same value for Mg)
! Ca2+ + CO32- = CaCO3 
keqaq_c(findloc(chraq_all,'ca',dim=1),ieqaq_co3) = &
    & k_arrhenius(10d0**(3.224d0),25d0+tempk_0,tc+tempk_0,3.545d0*cal2j,rg) ! from PHREEQC.DAT 
! Ca2+ + H+ + CO32- = CaHCO3
keqaq_c(findloc(chraq_all,'ca',dim=1),ieqaq_hco3) = &
    & k_arrhenius(10d0**(11.435d0),25d0+tempk_0,tc+tempk_0,-0.871d0*cal2j,rg) ! from PHREEQC.DAT 
! Ca+2 + SO4-2 = CaSO4
keqaq_s(findloc(chraq_all,'ca',dim=1),ieqaq_so4) = &
    & k_arrhenius(10d0**(2.25d0),25d0+tempk_0,tc+tempk_0,1.325d0*cal2j,rg) ! from PHREEQC.DAT 
! Ca+2 + NO3- = CaNO3+
! keqaq_no3(findloc(chraq_all,'ca',dim=1),ieqaq_no3) = &
    ! & k_arrhenius(10d0**(0.5d0),25d0+tempk_0,tc+tempk_0,-5.4d0,rg) ! from MINTEQV4.DAT           
! Ca+2 + NH4+ = CaNH3+2 + H+
! keqaq_nh3(findloc(chraq_all,'ca',dim=1),ieqaq_nh3) = &
    ! & k_arrhenius(10d0**(-9.144d0),25d0+tempk_0,tc+tempk_0,0d0,rg) ! from MINTEQV4.DAT 
! Ca+2 + 2NH4+ = Ca(NH3)2+2 + 2H+
! ignoring for now
! keqaq_nh3(findloc(chraq_all,'ca',dim=1),ieqaq_nh32) = &
    ! & k_arrhenius(10d0**(-18.788d0),25d0+tempk_0,tc+tempk_0,0d0,rg) ! from MINTEQV4.DAT 

    
! Fe2+ + H2O = Fe(OH)+ + H+
keqaq_h(findloc(chraq_all,'fe2',dim=1),ieqaq_h1) = &
    & k_arrhenius(10d0**(-9.51d0),25d0+tempk_0,tc+tempk_0, 40.3d0,rg) ! from Kanzaki and Murakami 2016
! Fe2+ + CO32- = FeCO3 
keqaq_c(findloc(chraq_all,'fe2',dim=1),ieqaq_co3) = &
    & k_arrhenius(10d0**(5.69d0),25d0+tempk_0,tc+tempk_0, -45.6d0,rg) ! from Kanzaki and Murakami 2016
! Fe2+ + H+ + CO32- = FeHCO3
keqaq_c(findloc(chraq_all,'fe2',dim=1),ieqaq_hco3) = &
    & k_arrhenius(10d0**(1.47d0),25d0+tempk_0,tc+tempk_0, -18d0,rg) &! from Kanzaki and Murakami 2016 
    & /keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h2) 
! Fe+2 + SO4-2 = FeSO4
keqaq_s(findloc(chraq_all,'fe2',dim=1),ieqaq_so4) = &
    & k_arrhenius(10d0**(2.25d0),25d0+tempk_0,tc+tempk_0,3.230d0*cal2j,rg) ! from PHREEQC.DAT 


! Fe3+ + H2O = Fe(OH)2+ + H+
keqaq_h(findloc(chraq_all,'fe3',dim=1),ieqaq_h1) = &
    & k_arrhenius(10d0**(-2.19d0),25d0+tempk_0,tc+tempk_0,10.4d0*cal2j,rg) ! from PHREEQC.DAT 
! Fe3+ + 2H2O = Fe(OH)2+ + 2H+
keqaq_h(findloc(chraq_all,'fe3',dim=1),ieqaq_h2) = &
    & k_arrhenius(10d0**(-5.67d0),25d0+tempk_0,tc+tempk_0,17.1d0*cal2j,rg) ! from PHREEQC.DAT 
! Fe3+ + 3H2O = Fe(OH)3 + 3H+
keqaq_h(findloc(chraq_all,'fe3',dim=1),ieqaq_h3) = &
    & k_arrhenius(10d0**(-12.56d0),25d0+tempk_0,tc+tempk_0,24.8d0*cal2j,rg) ! from PHREEQC.DAT 
! Fe3+ + 4H2O = Fe(OH)4- + 4H+
keqaq_h(findloc(chraq_all,'fe3',dim=1),ieqaq_h4) = &
    & k_arrhenius(10d0**(-21.6d0),25d0+tempk_0,tc+tempk_0,31.9d0*cal2j,rg) ! from PHREEQC.DAT 
! Fe+3 + SO4-2 = FeSO4+
keqaq_s(findloc(chraq_all,'fe3',dim=1),ieqaq_so4) = &
    & k_arrhenius(10d0**(4.04d0),25d0+tempk_0,tc+tempk_0,3.91d0*cal2j,rg) ! from PHREEQC.DAT 
! Fe+3 + 2 SO4-2 = Fe(SO4)2-
! ignoring for now
! keqaq_s(findloc(chraq_all,'fe3',dim=1),ieqaq_so42) = &
    ! & k_arrhenius(10d0**(5.38d0),25d0+tempk_0,tc+tempk_0,4.60d0*cal2j,rg) ! from PHREEQC.DAT 
! Fe+3 + NO3- = FeNO3+2
! keqaq_no3(findloc(chraq_all,'fe3',dim=1),ieqaq_no3) = &
    ! & k_arrhenius(10d0**(1d0),25d0+tempk_0,tc+tempk_0,-37d0,rg) ! from MINTEQV4.DAT 



! Na+ + CO3-2 = NaCO3-
keqaq_c(findloc(chraq_all,'na',dim=1),ieqaq_co3) = & 
    & k_arrhenius(10d0**(1.27d0),25d0+tempk_0,tc+tempk_0, 8.91d0*cal2j,rg) ! from PHREEQC.DAT 
! Na+ + H + CO3- = NaHCO3
keqaq_c(findloc(chraq_all,'na',dim=1),ieqaq_hco3) = & 
    & k_arrhenius(10d0**(-0.25d0),25d0+tempk_0,tc+tempk_0, -1d0*cal2j,rg) &! from PHREEQC.DAT for Na+ + HCO3- = NaHCO3
    & /keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h2)  ! HCO3- = CO32- + H+
! Na+ + SO4-2 = NaSO4-
keqaq_s(findloc(chraq_all,'na',dim=1),ieqaq_so4) = & 
    & k_arrhenius(10d0**(0.7d0),25d0+tempk_0,tc+tempk_0, 1.120d0*cal2j,rg) ! from PHREEQC.DAT 



! K+ + SO4-2 = KSO4-
keqaq_s(findloc(chraq_all,'k',dim=1),ieqaq_so4) = & 
    & k_arrhenius(10d0**(0.85d0),25d0+tempk_0,tc+tempk_0, 2.250d0*cal2j,rg) ! from PHREEQC.DAT 


! keqaq_s = 0d0


!!! ----------- Solid phases ------------------------!!
ksld_all = 0d0 
keqsld_all = 0d0

call get_mgasx_all( &
    & nz,nsp_gas_all,nsp_gas,nsp_gas_cnst &
    & ,chrgas,chrgas_all,chrgas_cnst &
    & ,mgas,mgasc &
    & ,mgas_loc  &! output
    & )

do isps = 1, nsp_sld_all
    mv_tmp = mv_all(isps)
    mineral = chrsld_all(isps)
    
    call sld_kin( &
        & nz,rg,tc,sec2yr,tempk_0,pro,poro,hr,kw,kho,mv_tmp &! input
        & ,nsp_gas_all,chrgas_all,mgas_loc &! input
        & ,mineral,'xxxxx' &! input 
        & ,kin,dkin_dmsp &! output
        & ) 
    ksld_all(isps,:) = kin
    
    ! check for solid solution 
    select case (trim(adjustl(mineral))) 
        case('la','ab','an','by','olg','and')
            ss_x = staq_all(isps, findloc(chraq_all,'ca',dim=1))
            ss_y = 0d0 ! non-zero if it is a solid solution 
        case('cpx','hb','dp') 
            ss_x = staq_all(isps, findloc(chraq_all,'fe2',dim=1))
            ss_y = 0d0 ! non-zero if it is a solid solution 
        case('opx','en','fer') 
            ss_x = staq_all(isps, findloc(chraq_all,'fe2',dim=1))
            ss_y = 0d0 ! non-zero if it is a solid solution 
        case('agt') 
            ss_y = 1d0 - staq_all(isps, findloc(chraq_all,'ca',dim=1))
            ss_x = staq_all(isps, findloc(chraq_all,'fe2',dim=1))/(1d0+ ss_y ) ! non-zero if it is a solid solution 
        case default 
            ss_x = 0d0 ! non-zero if it is a solid solution 
            ss_y = 0d0 ! non-zero if it is a solid solution 
    endselect 
    
    call sld_therm( &
        & rg,tc,tempk_0,ss_x,ss_y &! input
        & ,mineral &! input
        & ,therm &! output
        & ) 
    
    ! correction of thermodynamic data wrt primary species
    select case (trim(adjustl(mineral))) 
        case('anl')
            ! replacing Al(OH)42- with Al+++ as primary Al species
            therm = therm/keqaq_h(findloc(chraq_all,'al',dim=1),ieqaq_h4)
        case default 
            ! do nothing
    endselect 
    
    keqsld_all(isps) = therm
enddo


!--------- other reactions -------------! 
krxn1_ext_all = 0d0
krxn2_ext_all = 0d0

krxn1_ext_all(findloc(chrrxn_ext_all,'fe2o2',dim=1),:) = &
    & 1d0
    ! & max(8.0d13*60.0d0*24.0d0*365.0d0*(kw/pro)**2.0d0, 1d-7*60.0d0*24.0d0*365.0d0) &   
    ! mol L^-1 yr^-1 (25 deg C), Singer and Stumm (1970)excluding the term (c*po2)
    ! & *merge(0d0,1d0,po2<po2th*thon)
     
krxn1_ext_all(findloc(chrrxn_ext_all,'resp',dim=1),:) = 0.71d0 ! vmax mol m^-3, yr^-1, max soil respiration, Wood et al. (1993)
krxn1_ext_all(findloc(chrrxn_ext_all,'resp',dim=1),:) = &
    & krxn1_ext_all(findloc(chrrxn_ext_all,'resp',dim=1),:) !*1d1 ! reducing a bit to be fitted with modern soil pco2

krxn2_ext_all(findloc(chrrxn_ext_all,'resp',dim=1),:) = 0.121d0 ! mo2 Michaelis, Davidson et al. (2012)
     
     
krxn1_ext_all(findloc(chrrxn_ext_all,'omomb',dim=1),:) = 0.01d0*24d0*365d0 ! mg C mg-1 MBC yr-1
! converted from 0.01 mg C mg-1 MBC hr-1 Georgiou et al. (2017)

krxn2_ext_all(findloc(chrrxn_ext_all,'omomb',dim=1),:) = 250d0 ! mg C g-1 soil  Georgiou et al. (2017)
     
     
krxn1_ext_all(findloc(chrrxn_ext_all,'ombto',dim=1),:) = 0.00028d0*24d0*365d0 ! mg C mg-1 MBC yr-1
! converted from 0.00028 mg C mg-1 MBC hr-1 Georgiou et al. (2017)

krxn2_ext_all(findloc(chrrxn_ext_all,'ombto',dim=1),:) = 2d0 ! beta value Georgiou et al. (2017)




krxn1_ext_all(findloc(chrrxn_ext_all,'pyfe3',dim=1),:) = & 
    & 10.0d0**(-6.07d0)*60.0d0*60.0d0*24.0d0*365.0d0  !! excluding the term (fe3**0.93/fe2**0.40)  


endsubroutine coefs_v2

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine sld_kin( &
    & nz,rg,tc,sec2yr,tempk_0,prox,poro,hr,kw,kho,mv_tmp &! input
    & ,nsp_gas_all,chrgas_all,mgas_loc &! input
    & ,mineral,dev_sp &! input 
    & ,kin,dkin_dmsp &! output
    & ) 
implicit none

integer,intent(in)::nz
real(kind=8),intent(in)::rg,tc,sec2yr,tempk_0,mv_tmp,kw,kho
real(kind=8),dimension(nz),intent(in)::prox,poro,hr

real(kind=8) :: cal2j = 4.184d0 

character(5),intent(in)::mineral,dev_sp
real(kind=8),dimension(nz),intent(out)::kin,dkin_dmsp
real(kind=8) mh,moh,kinn_ref,kinh_ref,kinoh_ref,ean,eah,eaoh,tc_ref

integer,intent(in)::nsp_gas_all
character(5),dimension(nsp_gas_all),intent(in)::chrgas_all
real(kind=8),dimension(nsp_gas_all,nz),intent(in)::mgas_loc

real(kind=8),dimension(nz) :: pco2
real(kind=8) mco2,kinco2_ref,eaco2

! real(kind=8) k_arrhenius


kin = 0d0
dkin_dmsp = 0d0

select case(trim(adjustl(mineral)))
    case('ka')
        mh = 0.777d0
        moh = -0.472d0
        kinn_ref = 10d0**(-13.18d0)*sec2yr
        kinh_ref = 10d0**(-11.31d0)*sec2yr
        kinoh_ref = 10d0**(-17.05d0)*sec2yr
        ean = 22.2d0
        eah = 65.9d0
        eaoh = 17.9d0
        tc_ref = 25d0
        ! from Palandri and Kharaka, 2004)
        kin = ( & 
            & k_arrhenius(kinn_ref,tc_ref+tempk_0,tc+tempk_0,ean,rg) &
            & + prox**mh*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
            & + prox**moh*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
            & ) 
        select case(trim(adjustl(dev_sp)))
            case('pro')
                dkin_dmsp = ( & 
                    & + mh*prox**(mh-1d0)*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
                    & + moh*prox**(moh-1d0)*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
                    & ) 
            case default 
                dkin_dmsp = 0d0
        endselect 
    
    case('ab')
        mh = 0.457d0
        moh = -0.572d0
        kinn_ref = 10d0**(-12.56d0)*sec2yr
        kinh_ref = 10d0**(-10.16d0)*sec2yr
        kinoh_ref = 10d0**(-15.6d0)*sec2yr
        ean = 69.8d0
        eah = 65d0
        eaoh = 71d0
        tc_ref = 25d0
        ! from Palandri and Kharaka, 2004)
        kin = ( & 
            & k_arrhenius(kinn_ref,tc_ref+tempk_0,tc+tempk_0,ean,rg) &
            & + prox**mh*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
            & + prox**moh*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
            & ) 
        select case(trim(adjustl(dev_sp)))
            case('pro')
                dkin_dmsp = ( & 
                    & + mh*prox**(mh-1d0)*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
                    & + moh*prox**(moh-1d0)*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
                    & ) 
            case default 
                dkin_dmsp = 0d0
        endselect 

    case('kfs')
        mh = 0.5d0
        moh = -0.823d0
        kinn_ref = 10d0**(-12.41d0)*sec2yr
        kinh_ref = 10d0**(-10.06d0)*sec2yr
        kinoh_ref = 10d0**(-9.68d0)*sec2yr*kw**(-moh)
        ean = 9.08*cal2j
        eah = 12.4d0*cal2j
        eaoh = 22.5d0*cal2j
        tc_ref = 25d0
        ! from Brantley et al 2008
        kin = ( & 
            & k_arrhenius(kinn_ref,tc_ref+tempk_0,tc+tempk_0,ean,rg) &
            & + prox**mh*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
            & + prox**moh*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
            & ) 
        select case(trim(adjustl(dev_sp)))
            case('pro')
                dkin_dmsp = ( & 
                    & + mh*prox**(mh-1d0)*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
                    & + moh*prox**(moh-1d0)*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
                    & ) 
            case default 
                dkin_dmsp = 0d0
        endselect 

    case('fo')
        mh = 0.47d0
        moh = 0d0
        kinn_ref = 10d0**(-10.64d0)*sec2yr
        kinh_ref = 10d0**(-6.85d0)*sec2yr
        kinoh_ref = 0d0
        ean = 79d0
        eah = 67.2d0
        eaoh = 0d0
        tc_ref = 25d0
        ! from Palandri and Kharaka, 2004
        kin = ( & 
            & k_arrhenius(kinn_ref,tc_ref+tempk_0,tc+tempk_0,ean,rg) &
            & + prox**mh*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
            & + prox**moh*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
            & ) 
        select case(trim(adjustl(dev_sp)))
            case('pro')
                dkin_dmsp = ( & 
                    & + mh*prox**(mh-1d0)*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
                    & + moh*prox**(moh-1d0)*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
                    & ) 
            case default 
                dkin_dmsp = 0d0
        endselect 

    case('fa')
        mh = 1d0
        moh = 0d0
        kinn_ref = 10d0**(-12.80d0)*sec2yr
        kinh_ref = 10d0**(-4.80d0)*sec2yr
        kinoh_ref = 0d0
        ean = 94.4d0
        eah = 94.4d0
        eaoh = 0d0
        tc_ref = 25d0
        ! from Palandri and Kharaka, 2004
        kin = ( & 
            & k_arrhenius(kinn_ref,tc_ref+tempk_0,tc+tempk_0,ean,rg) &
            & + prox**mh*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
            & + prox**moh*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
            & ) 
        select case(trim(adjustl(dev_sp)))
            case('pro')
                dkin_dmsp = ( & 
                    & + mh*prox**(mh-1d0)*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
                    & + moh*prox**(moh-1d0)*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
                    & ) 
            case default 
                dkin_dmsp = 0d0
        endselect 

    case('an')
        mh = 1.411d0
        moh = 0d0
        kinn_ref = 10d0**(-9.12d0)*sec2yr
        kinh_ref = 10d0**(-3.5d0)*sec2yr
        kinoh_ref = 0d0
        ean = 17.8d0
        eah = 16.6d0
        eaoh = 0d0
        tc_ref = 25d0
        ! from Palandri and Kharaka, 2004
        kin = ( & 
            & k_arrhenius(kinn_ref,tc_ref+tempk_0,tc+tempk_0,ean,rg) &
            & + prox**mh*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
            & + prox**moh*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
            & ) 
        select case(trim(adjustl(dev_sp)))
            case('pro')
                dkin_dmsp = ( & 
                    & + mh*prox**(mh-1d0)*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
                    & + moh*prox**(moh-1d0)*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
                    & ) 
            case default 
                dkin_dmsp = 0d0
        endselect 

    case('la')
        mh = 0.626d0
        moh = 0d0
        kinn_ref = 10d0**(-10.91d0)*sec2yr
        kinh_ref = 10d0**(-7.87d0)*sec2yr
        kinoh_ref = 0d0
        ean = 45.2d0
        eah = 42.1d0
        eaoh = 0d0
        tc_ref = 25d0
        ! from Palandri and Kharaka, 2004
        kin = ( & 
            & k_arrhenius(kinn_ref,tc_ref+tempk_0,tc+tempk_0,ean,rg) &
            & + prox**mh*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
            & + prox**moh*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
            & ) 
        select case(trim(adjustl(dev_sp)))
            case('pro')
                dkin_dmsp = ( & 
                    & + mh*prox**(mh-1d0)*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
                    & + moh*prox**(moh-1d0)*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
                    & ) 
            case default 
                dkin_dmsp = 0d0
        endselect 

    case('and')
        mh = 0.541d0
        moh = 0d0
        kinn_ref = 10d0**(-11.47d0)*sec2yr
        kinh_ref = 10d0**(-8.88d0)*sec2yr
        kinoh_ref = 0d0
        ean = 57.4d0
        eah = 53.5d0
        eaoh = 0d0
        tc_ref = 25d0
        ! from Palandri and Kharaka, 2004
        kin = ( & 
            & k_arrhenius(kinn_ref,tc_ref+tempk_0,tc+tempk_0,ean,rg) &
            & + prox**mh*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
            & + prox**moh*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
            & ) 
        select case(trim(adjustl(dev_sp)))
            case('pro')
                dkin_dmsp = ( & 
                    & + mh*prox**(mh-1d0)*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
                    & + moh*prox**(moh-1d0)*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
                    & ) 
            case default 
                dkin_dmsp = 0d0
        endselect 

    case('olg')
        mh = 0.457d0
        moh = 0d0
        kinn_ref = 10d0**(-11.84d0)*sec2yr
        kinh_ref = 10d0**(-9.67d0)*sec2yr
        kinoh_ref = 0d0
        ean = 69.8d0
        eah = 65.0d0
        eaoh = 0d0
        tc_ref = 25d0
        ! from Palandri and Kharaka, 2004
        kin = ( & 
            & k_arrhenius(kinn_ref,tc_ref+tempk_0,tc+tempk_0,ean,rg) &
            & + prox**mh*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
            & + prox**moh*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
            & ) 
        select case(trim(adjustl(dev_sp)))
            case('pro')
                dkin_dmsp = ( & 
                    & + mh*prox**(mh-1d0)*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
                    & + moh*prox**(moh-1d0)*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
                    & ) 
            case default 
                dkin_dmsp = 0d0
        endselect 

    case('by')
        mh = 1.018d0
        moh = 0d0
        kinn_ref = 10d0**(-9.82d0)*sec2yr
        kinh_ref = 10d0**(-5.85d0)*sec2yr
        kinoh_ref = 0d0
        ean = 31.5d0
        eah = 29.3d0
        eaoh = 0d0
        tc_ref = 25d0
        ! from Palandri and Kharaka, 2004
        kin = ( & 
            & k_arrhenius(kinn_ref,tc_ref+tempk_0,tc+tempk_0,ean,rg) &
            & + prox**mh*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
            & + prox**moh*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
            & ) 
        select case(trim(adjustl(dev_sp)))
            case('pro')
                dkin_dmsp = ( & 
                    & + mh*prox**(mh-1d0)*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
                    & + moh*prox**(moh-1d0)*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
                    & ) 
            case default 
                dkin_dmsp = 0d0
        endselect 

    case('cc')
        mh = 1d0
        moh = 0d0
        kinn_ref = 10d0**(-5.81d0)*sec2yr
        kinh_ref = 10d0**(-0.3d0)*sec2yr
        kinoh_ref = 0d0
        ean = 23.5d0
        eah = 14.4d0
        eaoh = 0d0
        tc_ref = 25d0
        ! adding co2 mechanism
        mco2 = 1d0
        kinco2_ref = 10d0**(-3.48d0)*sec2yr
        eaco2 = 35.4d0
        pco2 = mgas_loc(findloc(chrgas_all,'pco2',dim=1),:)
        ! from Palandri and Kharaka, 2004 (excluding carbonate mechanism)
        kin = ( & 
            & k_arrhenius(kinn_ref,tc_ref+tempk_0,tc+tempk_0,ean,rg) &
            & + prox**mh*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
            & + prox**moh*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
            & + pco2**mco2*k_arrhenius(kinco2_ref,tc_ref+tempk_0,tc+tempk_0,eaco2,rg) &
            & ) 
        select case(trim(adjustl(dev_sp)))
            case('pro')
                dkin_dmsp = ( & 
                    & + mh*prox**(mh-1d0)*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
                    & + moh*prox**(moh-1d0)*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
                    & ) 
            case('pco2')
                dkin_dmsp = ( & 
                    & + mco2*pco2**(mco2-1d0)*k_arrhenius(kinco2_ref,tc_ref+tempk_0,tc+tempk_0,eaco2,rg) &
                    & ) 
            case default 
                dkin_dmsp = 0d0
        endselect 

    case('arg')
        ! assumed to be the same as those for cc
        mh = 1d0
        moh = 0d0
        kinn_ref = 10d0**(-5.81d0)*sec2yr
        kinh_ref = 10d0**(-0.3d0)*sec2yr
        kinoh_ref = 0d0
        ean = 23.5d0
        eah = 14.4d0
        eaoh = 0d0
        tc_ref = 25d0
        ! adding co2 mechanism
        mco2 = 1d0
        kinco2_ref = 10d0**(-3.48d0)*sec2yr
        eaco2 = 35.4d0
        pco2 = mgas_loc(findloc(chrgas_all,'pco2',dim=1),:)
        ! from Palandri and Kharaka, 2004 (excluding carbonate mechanism)
        kin = ( & 
            & k_arrhenius(kinn_ref,tc_ref+tempk_0,tc+tempk_0,ean,rg) &
            & + prox**mh*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
            & + prox**moh*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
            & + pco2**mco2*k_arrhenius(kinco2_ref,tc_ref+tempk_0,tc+tempk_0,eaco2,rg) &
            & ) 
        select case(trim(adjustl(dev_sp)))
            case('pro')
                dkin_dmsp = ( & 
                    & + mh*prox**(mh-1d0)*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
                    & + moh*prox**(moh-1d0)*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
                    & ) 
            case('pco2')
                dkin_dmsp = ( & 
                    & + mco2*pco2**(mco2-1d0)*k_arrhenius(kinco2_ref,tc_ref+tempk_0,tc+tempk_0,eaco2,rg) &
                    & ) 
            case default 
                dkin_dmsp = 0d0
        endselect 

    case('dlm') ! for disordered dolomite
        mh = 0.500d0
        moh = 0d0
        kinn_ref = 10d0**(-7.53d0)*sec2yr
        kinh_ref = 10d0**(-3.19d0)*sec2yr
        kinoh_ref = 0d0
        ean = 52.2d0
        eah = 36.1d0
        eaoh = 0d0
        tc_ref = 25d0
        ! adding co2 mechanism
        mco2 = 0.5d0
        kinco2_ref = 10d0**(-5.11d0)*sec2yr
        eaco2 = 34.8d0
        pco2 = mgas_loc(findloc(chrgas_all,'pco2',dim=1),:)
        ! from Palandri and Kharaka, 2004 (excluding carbonate mechanism)
        kin = ( & 
            & k_arrhenius(kinn_ref,tc_ref+tempk_0,tc+tempk_0,ean,rg) &
            & + prox**mh*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
            & + prox**moh*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
            & + pco2**mco2*k_arrhenius(kinco2_ref,tc_ref+tempk_0,tc+tempk_0,eaco2,rg) &
            & ) 
        select case(trim(adjustl(dev_sp)))
            case('pro')
                dkin_dmsp = ( & 
                    & + mh*prox**(mh-1d0)*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
                    & + moh*prox**(moh-1d0)*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
                    & ) 
            case('pco2')
                dkin_dmsp = ( & 
                    & + mco2*pco2**(mco2-1d0)*k_arrhenius(kinco2_ref,tc_ref+tempk_0,tc+tempk_0,eaco2,rg) &
                    & ) 
            case default 
                dkin_dmsp = 0d0
        endselect 

    case('gb')
        mh = 0.992d0
        moh = -0.784d0
        kinn_ref = 10d0**(-11.50d0)*sec2yr
        kinh_ref = 10d0**(-7.65d0)*sec2yr
        kinoh_ref = 10d0**(-16.65d0)*sec2yr
        ean = 61.2d0
        eah = 47.5d0
        eaoh = 80.1d0
        tc_ref = 25d0
        ! from Palandri and Kharaka, 2004
        kin = ( & 
            & k_arrhenius(kinn_ref,tc_ref+tempk_0,tc+tempk_0,ean,rg) &
            & + prox**mh*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
            & + prox**moh*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
            & ) 
        select case(trim(adjustl(dev_sp)))
            case('pro')
                dkin_dmsp = ( & 
                    & + mh*prox**(mh-1d0)*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
                    & + moh*prox**(moh-1d0)*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
                    & ) 
            case default 
                dkin_dmsp = 0d0
        endselect 

    case('amsi')
        mh = 0d0
        moh = 0d0
        kinn_ref = 10d0**(-12.23d0)*sec2yr
        kinh_ref = 0d0
        kinoh_ref = 0d0
        ean = 74.5d0
        eah = 0d0
        eaoh = 0d0
        tc_ref = 25d0
        ! from Palandri and Kharaka, 2004
        kin = ( & 
            & k_arrhenius(kinn_ref,tc_ref+tempk_0,tc+tempk_0,ean,rg) &
            & + prox**mh*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
            & + prox**moh*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
            & ) 
        dkin_dmsp = 0d0

    case('qtz')
        mh = 0d0
        moh = 0d0
        kinn_ref = 10d0**(-13.40d0)*sec2yr
        kinh_ref = 0d0
        kinoh_ref = 0d0
        ean = 90.9d0
        eah = 0d0
        eaoh = 0d0
        tc_ref = 25d0
        ! from Palandri and Kharaka, 2004
        kin = ( & 
            & k_arrhenius(kinn_ref,tc_ref+tempk_0,tc+tempk_0,ean,rg) &
            & + prox**mh*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
            & + prox**moh*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
            & ) 
        dkin_dmsp = 0d0

    case('gt')
        mh = 0d0
        moh = 0d0
        kinn_ref = 10d0**(-7.94d0)*sec2yr
        kinh_ref = 0d0
        kinoh_ref = 0d0
        ean = 86.5d0
        eah = 0d0
        eaoh = 0d0
        tc_ref = 25d0
        ! from Palandri and Kharaka, 2004
        kin = ( & 
            & k_arrhenius(kinn_ref,tc_ref+tempk_0,tc+tempk_0,ean,rg) &
            & + prox**mh*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
            & + prox**moh*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
            & ) 
        dkin_dmsp = 0d0

    case('hm')
        mh = 1d0
        moh = 0d0
        kinn_ref = 10d0**(-14.60d0)*sec2yr
        kinh_ref = 10d0**(-9.39d0)*sec2yr
        kinoh_ref = 0d0
        ean = 66.2d0
        eah = 66.2d0
        eaoh = 0d0
        tc_ref = 25d0
        ! from Palandri and Kharaka, 2004
        kin = ( & 
            & k_arrhenius(kinn_ref,tc_ref+tempk_0,tc+tempk_0,ean,rg) &
            & + prox**mh*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
            & + prox**moh*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
            & ) 
        dkin_dmsp = 0d0

    case('ct')
        mh = 0d0
        moh = -0.23d0
        kinn_ref = 10d0**(-12d0)*sec2yr
        kinh_ref = 0d0
        kinoh_ref = 10d0**(-13.58d0)*sec2yr
        ean = 73.5d0
        eah = 0d0
        eaoh = 73.5d0
        tc_ref = 25d0
        ! from Palandri and Kharaka, 2004
        kin = ( & 
            & k_arrhenius(kinn_ref,tc_ref+tempk_0,tc+tempk_0,ean,rg) &
            & + prox**mh*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
            & + prox**moh*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
            & ) 
        select case(trim(adjustl(dev_sp)))
            case('pro')
                dkin_dmsp = ( & 
                    & + mh*prox**(mh-1d0)*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
                    & + moh*prox**(moh-1d0)*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
                    & ) 
            case default 
                dkin_dmsp = 0d0
        endselect 

    case('mscv')
        mh = 0.370d0
        moh = -0.22d0
        kinn_ref = 10d0**(-13.55d0)*sec2yr
        kinh_ref = 10d0**(-11.85d0)*sec2yr
        kinoh_ref = 10d0**(-13.55d0)*sec2yr
        ean = 22d0
        eah = 22d0
        eaoh = 22d0
        tc_ref = 25d0
        ! from Palandri and Kharaka, 2004
        kin = ( & 
            & k_arrhenius(kinn_ref,tc_ref+tempk_0,tc+tempk_0,ean,rg) &
            & + prox**mh*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
            & + prox**moh*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
            & ) 
        select case(trim(adjustl(dev_sp)))
            case('pro')
                dkin_dmsp = ( & 
                    & + mh*prox**(mh-1d0)*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
                    & + moh*prox**(moh-1d0)*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
                    & ) 
            case default 
                dkin_dmsp = 0d0
        endselect 

    case('plgp')
        mh = 0d0
        moh = 0d0
        kinn_ref = 10d0**(-12.4d0)*sec2yr
        kinh_ref = 0d0
        kinoh_ref = 0d0
        ean = 29d0
        eah = 0d0
        eaoh = 0d0
        tc_ref = 25d0
        ! from Palandri and Kharaka, 2004
        kin = ( & 
            & k_arrhenius(kinn_ref,tc_ref+tempk_0,tc+tempk_0,ean,rg) &
            & + prox**mh*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
            & + prox**moh*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
            & ) 
        select case(trim(adjustl(dev_sp)))
            case('pro')
                dkin_dmsp = ( & 
                    & + mh*prox**(mh-1d0)*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
                    & + moh*prox**(moh-1d0)*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
                    & ) 
            case default 
                dkin_dmsp = 0d0
        endselect 

    case('cabd','ill','kbd','nabd','mgbd') ! illite kinetics is assumed to be the same as smectite (Bibi et al., 2011)
        mh = 0.34d0
        moh = -0.4d0
        kinn_ref = 10d0**(-12.78d0)*sec2yr
        kinh_ref = 10d0**(-10.98d0)*sec2yr
        kinoh_ref = 10d0**(-16.52d0)*sec2yr
        ean = 35d0
        eah = 23.6d0
        eaoh = 58.9d0
        tc_ref = 25d0
        ! from Palandri and Kharaka, 2004
        kin = ( & 
            & k_arrhenius(kinn_ref,tc_ref+tempk_0,tc+tempk_0,ean,rg) &
            & + prox**mh*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
            & + prox**moh*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
            & ) 
        select case(trim(adjustl(dev_sp)))
            case('pro')
                dkin_dmsp = ( & 
                    & + mh*prox**(mh-1d0)*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
                    & + moh*prox**(moh-1d0)*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
                    & ) 
            case default 
                dkin_dmsp = 0d0
        endselect 

    case('nph','anl') ! analcime kinetics is assumed to be the same as nepherine (cf. Ragnarsdottir, GCA, 1993)
        mh = 1.130d0
        moh = -0.200d0
        kinn_ref = 10d0**(-8.56d0)*sec2yr
        kinh_ref = 10d0**(-2.73d0)*sec2yr
        kinoh_ref = 10d0**(-10.76d0)*sec2yr
        ean = 65.4d0
        eah = 62.9d0
        eaoh = 37.8d0
        tc_ref = 25d0
        ! from Palandri and Kharaka, 2004
        kin = ( & 
            & k_arrhenius(kinn_ref,tc_ref+tempk_0,tc+tempk_0,ean,rg) &
            & + prox**mh*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
            & + prox**moh*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
            & ) 
        select case(trim(adjustl(dev_sp)))
            case('pro')
                dkin_dmsp = ( & 
                    & + mh*prox**(mh-1d0)*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
                    & + moh*prox**(moh-1d0)*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
                    & ) 
            case default 
                dkin_dmsp = 0d0
        endselect 

    case('dp')
        mh = 0.71d0
        moh = 0d0
        kinn_ref = 10d0**(-11.11d0)*sec2yr
        kinh_ref = 10d0**(-6.36d0)*sec2yr
        kinoh_ref = 0d0
        ean = 50.6d0
        eah = 96.1d0
        eaoh = 0d0
        tc_ref = 25d0
        ! from Palandri and Kharaka, 2004
        kin = ( & 
            & k_arrhenius(kinn_ref,tc_ref+tempk_0,tc+tempk_0,ean,rg) &
            & + prox**mh*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
            & + prox**moh*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
            & ) 
        select case(trim(adjustl(dev_sp)))
            case('pro')
                dkin_dmsp = ( & 
                    & + mh*prox**(mh-1d0)*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
                    & + moh*prox**(moh-1d0)*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
                    & ) 
            case default 
                dkin_dmsp = 0d0
        endselect 
    
    case('hb','cpx','agt')
        mh = 0.70d0
        moh = 0d0
        kinn_ref = 10d0**(-11.97d0)*sec2yr
        kinh_ref = 10d0**(-6.82d0)*sec2yr
        kinoh_ref = 0d0
        ean = 78.0d0
        eah = 78.0d0
        eaoh = 0d0
        tc_ref = 25d0
        ! for augite from Palandri and Kharaka, 2004
        kin = ( & 
            & k_arrhenius(kinn_ref,tc_ref+tempk_0,tc+tempk_0,ean,rg) &
            & + prox**mh*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
            & + prox**moh*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
            & ) 
        select case(trim(adjustl(dev_sp)))
            case('pro')
                dkin_dmsp = ( & 
                    & + mh*prox**(mh-1d0)*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
                    & + moh*prox**(moh-1d0)*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
                    & ) 
            case default 
                dkin_dmsp = 0d0
        endselect 
    
    case('en','opx','fer')
        mh = 0.60d0
        moh = 0d0
        kinn_ref = 10d0**(-12.72d0)*sec2yr
        kinh_ref = 10d0**(-9.02d0)*sec2yr
        kinoh_ref = 0d0
        ean = 80.0d0
        eah = 80.0d0
        eaoh = 0d0
        tc_ref = 25d0
        ! for enstatite from Palandri and Kharaka, 2004
        kin = ( & 
            & k_arrhenius(kinn_ref,tc_ref+tempk_0,tc+tempk_0,ean,rg) &
            & + prox**mh*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
            & + prox**moh*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
            & ) 
        select case(trim(adjustl(dev_sp)))
            case('pro')
                dkin_dmsp = ( & 
                    & + mh*prox**(mh-1d0)*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
                    & + moh*prox**(moh-1d0)*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
                    & ) 
            case default 
                dkin_dmsp = 0d0
        endselect 
    
    case('tm')
        mh = 0.70d0
        moh = 0d0
        kinn_ref = 10d0**(-10.60d0)*sec2yr
        kinh_ref = 10d0**(-8.40d0)*sec2yr
        kinoh_ref = 0d0
        ean = 94.4d0
        eah = 18.9d0
        eaoh = 0d0
        tc_ref = 25d0
        ! from Palandri and Kharaka, 2004
        kin = ( & 
            & k_arrhenius(kinn_ref,tc_ref+tempk_0,tc+tempk_0,ean,rg) &
            & + prox**mh*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
            & + prox**moh*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
            & ) 
        select case(trim(adjustl(dev_sp)))
            case('pro')
                dkin_dmsp = ( & 
                    & + mh*prox**(mh-1d0)*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
                    & + moh*prox**(moh-1d0)*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
                    & ) 
            case default 
                dkin_dmsp = 0d0
        endselect 
    
    case('antp')
        mh = 0.440d0
        moh = 0d0
        kinn_ref = 10d0**(-14.24d0)*sec2yr
        kinh_ref = 10d0**(-11.94d0)*sec2yr
        kinoh_ref = 0d0
        ean = 51.0d0
        eah = 51.0d0
        eaoh = 0d0
        tc_ref = 25d0
        ! from Palandri and Kharaka, 2004
        kin = ( & 
            & k_arrhenius(kinn_ref,tc_ref+tempk_0,tc+tempk_0,ean,rg) &
            & + prox**mh*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
            & + prox**moh*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
            & ) 
        select case(trim(adjustl(dev_sp)))
            case('pro')
                dkin_dmsp = ( & 
                    & + mh*prox**(mh-1d0)*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
                    & + moh*prox**(moh-1d0)*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
                    & ) 
            case default 
                dkin_dmsp = 0d0
        endselect 
    
    case('gps')
        mh = 0d0
        moh = 0d0
        kinn_ref = 10d0**(-2.79d0)*sec2yr
        kinh_ref = 0d0
        kinoh_ref = 0d0
        ean = 0d0
        eah = 0d0
        eaoh = 0d0
        tc_ref = 25d0
        ! from Palandri and Kharaka, 2004
        kin = ( & 
            & k_arrhenius(kinn_ref,tc_ref+tempk_0,tc+tempk_0,ean,rg) &
            & + prox**mh*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
            & + prox**moh*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
            & ) 
        select case(trim(adjustl(dev_sp)))
            case('pro')
                dkin_dmsp = ( & 
                    & + mh*prox**(mh-1d0)*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
                    & + moh*prox**(moh-1d0)*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
                    & ) 
            case default 
                dkin_dmsp = 0d0
        endselect 
        
    case('py')
        mh = 0d0
        moh = -0.11d0
        kinn_ref = 0d0
        kinh_ref = 0d0
        kinoh_ref = 10.0d0**(-8.19d0)*sec2yr*kho**0.5d0
        ean = 0d0
        eah = 0d0
        eaoh = 57d0
        tc_ref = 15d0
        ! from Williamson and Rimstidt (1994)
        kin = ( & 
            & k_arrhenius(kinn_ref,tc_ref+tempk_0,tc+tempk_0,ean,rg) &
            & + prox**mh*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
            & + prox**moh*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
            & ) 
        select case(trim(adjustl(dev_sp)))
            case('pro')
                dkin_dmsp = ( & 
                    & + mh*prox**(mh-1d0)*k_arrhenius(kinh_ref,tc_ref+tempk_0,tc+tempk_0,eah,rg) &
                    & + moh*prox**(moh-1d0)*k_arrhenius(kinoh_ref,tc_ref+tempk_0,tc+tempk_0,eaoh,rg) &
                    & ) 
            case default 
                dkin_dmsp = 0d0
        endselect 
        
    case('g1')
        kin = ( &
            & 1d0/1d0 &! mol m^-2 yr^-1, just a value assumed; turnover time of 1 year as in Chen et al. (2010, AFM) 
            & )
        dkin_dmsp = 0d0
        
    case('g2')
        kin = ( &
            & 1d0/8d0 &! mol m^-2 yr^-1, just a value assumed; turnover time of 8 year as in Chen et al. (2010, AFM) 
            & )
        dkin_dmsp = 0d0
        
    case('g3')
        kin = ( &
            & 1d0/1d3 &! mol m^-2 yr^-1, just a value assumed; picked up to represent turnover time of 1k year  
            & )
        dkin_dmsp = 0d0
        
    case default 
        kin =0d0
        dkin_dmsp = 0d0

endselect  


endsubroutine sld_kin

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine sld_therm( &
    & rg,tc,tempk_0,ss_x,ss_y &! input
    & ,mineral &! input
    & ,therm &! output
    & ) 
implicit none

real(kind=8),intent(in)::rg,tc,tempk_0,ss_x,ss_y
real(kind=8) :: cal2j = 4.184d0 
real(kind=8),intent(out):: therm
character(5),intent(in):: mineral
real(kind=8) tc_ref,ha,therm_ref,delG
real(kind=8) tc_ref_1,ha_1,therm_ref_1,therm_1,delG_1
real(kind=8) tc_ref_2,ha_2,therm_ref_2,therm_2,delG_2
real(kind=8) tc_ref_3,ha_3,therm_ref_3,therm_3,delG_3
real(kind=8) tc_ref_4,ha_4,therm_ref_4,therm_4,delG_4
real(kind=8) tc_ref_5,ha_5,therm_ref_5,therm_5,delG_5
real(kind=8) tc_ref_6,ha_6,therm_ref_6,therm_6,delG_6

! real(kind=8) k_arrhenius

therm = 0d0

select case(trim(adjustl(mineral))) 
    case('ka') 
        ! Al2Si2O5(OH)4 + 6 H+ = H2O + 2 H4SiO4 + 2 Al+3 
        therm_ref = 10d0**(7.435d0)
        ha = -35.3d0*cal2j
        tc_ref = 25d0
        ! from PHREEQC.DAT 
        therm = k_arrhenius(therm_ref,tc_ref+tempk_0,tc+tempk_0,ha,rg)
    ! case('ab')
        ! NaAlSi3O8 + 4 H+ = Na+ + Al3+ + 3SiO2 + 2H2O
        ! therm_ref = 10d0**3.412182823d0
        ! ha = -54.15042876d0
        ! tc_ref = 15d0
        ! from Kanzaki and Murakami 2018
        ! therm = k_arrhenius(therm_ref,tc_ref+tempk_0,tc+tempk_0,ha,rg)
    case('kfs')
        ! K-feldspar  + 4 H+  = 2 H2O  + K+  + Al+++  + 3 SiO2(aq)
        therm_ref = 10d0**0.227294204d0
        ha = -26.30862098d0
        tc_ref = 15d0
        ! from Kanzaki and Murakami 2018
        therm = k_arrhenius(therm_ref,tc_ref+tempk_0,tc+tempk_0,ha,rg)
    case('anl')
        ! NaAlSi2O6*H2O  + 5 H2O  = Na+  + Al(OH)4-  + 2 Si(OH)4(aq)
        therm_ref = 10d0**(-16.06d0)
        ha = 101d0
        tc_ref = 25d0
        ! from Wilkin and Barnes 1998
        therm = k_arrhenius(therm_ref,tc_ref+tempk_0,tc+tempk_0,ha,rg)
    case('nph')
        ! Nepheline  + 4 H+  = 2 H2O  + SiO2(aq)  + Al+++  + Na+
        therm_ref = 10d0**(14.93646757d0)
        ha = -130.8197467d0
        tc_ref = 15d0
        ! from Kanzaki and Murakami 2018
        therm = k_arrhenius(therm_ref,tc_ref+tempk_0,tc+tempk_0,ha,rg)
    case('fo')
        ! Fo + 4H+ = 2Mg2+ + SiO2(aq) + 2H2O
        therm_ref = 10d0**29.41364324d0
        ha = -208.5932252d0
        tc_ref = 15d0
        ! from Kanzaki and Murakami 2018
        therm = k_arrhenius(therm_ref,tc_ref+tempk_0,tc+tempk_0,ha,rg)
    case('fa')
        ! Fa + 4H+ = 2Fe2+ + SiO2(aq) + 2H2O
        therm_ref = 10d0**19.98781342d0
        ha = -153.7676621d0
        tc_ref = 15d0
        ! from Kanzaki and Murakami 2018
        therm = k_arrhenius(therm_ref,tc_ref+tempk_0,tc+tempk_0,ha,rg)
    ! case('an')
        ! CaAl2Si2O8 + 8H+ = Ca2+ + 2 Al3+ + 2SiO2 + 4H2O
        ! therm_ref = 10d0**28.8615308d0
        ! ha = -292.8769275d0
        ! tc_ref = 15d0
        ! from Kanzaki and Murakami 2018
        ! therm = k_arrhenius(therm_ref,tc_ref+tempk_0,tc+tempk_0,ha,rg)
    case('cc')
        ! CaCO3 = Ca2+ + CO32-
        therm_ref = 10d0**(-8.43d0)
        ha = -8.028943471d0
        tc_ref = 15d0
        ! from Kanzaki and Murakami 2015
        therm = k_arrhenius(therm_ref,tc_ref+tempk_0,tc+tempk_0,ha,rg)
    case('arg')
        ! CaCO3 = Ca2+ + CO32-
        therm_ref = 10d0**(-8.3d0)
        ha = -12d0
        tc_ref = 25d0
        ! from minteq.v4
        therm = k_arrhenius(therm_ref,tc_ref+tempk_0,tc+tempk_0,ha,rg)
    case('dlm') ! disordered
        ! CaMg(CO3)2 = Ca+2 + Mg+2 + 2CO3-2
        therm_ref = 10d0**(-16.54d0)
        ha = -46.4d0
        tc_ref = 25d0
        ! from minteq.v4
        therm = k_arrhenius(therm_ref,tc_ref+tempk_0,tc+tempk_0,ha,rg)
    case('gb')
        ! Al(OH)3 + 3 H+ = Al+3 + 3 H2O
        therm_ref = 10d0**(8.11d0)
        ha = -22.80d0*cal2j
        tc_ref = 25d0
        ! from PHREEQC.DAT 
        therm = k_arrhenius(therm_ref,tc_ref+tempk_0,tc+tempk_0,ha,rg)
    case('amsi')
        ! SiO2 + 2 H2O = H4SiO4
        therm_ref = 10d0**(-2.71d0)
        ha = 3.340d0*cal2j
        tc_ref = 25d0
        ! from PHREEQC.DAT 
        therm = k_arrhenius(therm_ref,tc_ref+tempk_0,tc+tempk_0,ha,rg)
    case('qtz')
        ! SiO2 + 2H2O = H4SiO4
        therm_ref = 10d0**(-4d0)
        ha = 22.36d0
        tc_ref = 25d0
        ! from minteq.v4 
        therm = k_arrhenius(therm_ref,tc_ref+tempk_0,tc+tempk_0,ha,rg)
    case('gt')
        ! Fe(OH)3 + 3 H+ = Fe+3 + 2 H2O
        therm_ref = 10d0**(0.5345d0)
        ha = -61.53703d0
        tc_ref = 25d0
        ! from Sugimori et al. 2012 
        therm = k_arrhenius(therm_ref,tc_ref+tempk_0,tc+tempk_0,ha,rg)
    case('hm')
        ! Fe2O3 + 6H+ = 2Fe+3 + 3H2O
        therm_ref = 10d0**(-1.418d0)
        ha = -128.987d0
        tc_ref = 25d0
        ! from minteq.v4
        therm = k_arrhenius(therm_ref,tc_ref+tempk_0,tc+tempk_0,ha,rg)
    case('ct')
        ! Mg3Si2O5(OH)4 + 6 H+ = H2O + 2 H4SiO4 + 3 Mg+2
        therm_ref = 10d0**(32.2d0)
        ha = -46.800d0*cal2j
        tc_ref = 25d0
        ! from PHREEQC.DAT 
        therm = k_arrhenius(therm_ref,tc_ref+tempk_0,tc+tempk_0,ha,rg)
    case('mscv')
        ! KAl2(AlSi3O10)(OH)2 + 10 H+  = 6 H2O  + 3 SiO2(aq)  + K+  + 3 Al+++
        therm_ref = 10d0**(15.97690572d0)
        ha = -230.7845245d0
        tc_ref = 15d0
        ! from Kanzaki & Murakami 2018 
        therm = k_arrhenius(therm_ref,tc_ref+tempk_0,tc+tempk_0,ha,rg)
    case('plgp')
        ! KMg3(AlSi3O10)(OH)2 + 10 H+  = 6 H2O  + 3 SiO2(aq)  + Al+++  + K+  + 3 Mg++
        therm_ref = 10d0**(40.12256823d0)
        ha = -312.7817497d0
        tc_ref = 15d0
        ! from Kanzaki & Murakami 2018 
        therm = k_arrhenius(therm_ref,tc_ref+tempk_0,tc+tempk_0,ha,rg)
    case('cabd')
        ! Beidellit-Ca  + 7.32 H+  = 4.66 H2O  + 2.33 Al+++  + 3.67 SiO2(aq)  + .165 Ca++
        therm_ref = 10d0**(7.269946518d0)
        ha = -157.0186168d0
        tc_ref = 15d0
        ! from Kanzaki & Murakami 2018
        therm = k_arrhenius(therm_ref,tc_ref+tempk_0,tc+tempk_0,ha,rg)
    case('mgbd')
        ! Beidellit-Mg  + 7.32 H+  = 4.66 H2O  + 2.33 Al+++  + 3.67 SiO2(aq)  + .165 Mg++
        therm_ref = 10d0**(7.270517113d0)
        ha = -160.1864268d0
        tc_ref = 15d0
        ! from Kanzaki & Murakami 2018
        therm = k_arrhenius(therm_ref,tc_ref+tempk_0,tc+tempk_0,ha,rg)
    case('nabd')
        ! Beidellit-Na  + 7.32 H+  = 4.66 H2O  + 2.33 Al+++  + 3.67 SiO2(aq)  + .33 Na+
        therm_ref = 10d0**(7.288837383d0)
        ha = -150.7328834d0
        tc_ref = 15d0
        ! from Kanzaki & Murakami 2018
        therm = k_arrhenius(therm_ref,tc_ref+tempk_0,tc+tempk_0,ha,rg)
    case('kbd')
        ! Beidellit-K  + 7.32 H+  = 4.66 H2O  + 2.33 Al+++  + 3.67 SiO2(aq)  + .33 K+
        therm_ref = 10d0**(6.928086412d0)
        ha = -145.6776905d0
        tc_ref = 15d0
        ! from Kanzaki & Murakami 2018
        therm = k_arrhenius(therm_ref,tc_ref+tempk_0,tc+tempk_0,ha,rg)
    case('ill')
        ! Illite  + 8 H+  = 5 H2O  + .6 K+  + .25 Mg++  + 2.3 Al+++  + 3.5 SiO2(aq)
        therm_ref = 10d0**(10.8063184d0)
        ha = -166.39733d0
        tc_ref = 15d0
        ! from Kanzaki & Murakami 2018
        therm = k_arrhenius(therm_ref,tc_ref+tempk_0,tc+tempk_0,ha,rg)
    ! case('dp')
        ! Diopside  + 4 H+  = Ca++  + 2 H2O  + Mg++  + 2 SiO2(aq)
        ! therm_ref = 10d0**(21.79853309d0)
        ! ha = -138.6020832d0
        ! tc_ref = 15d0
        ! from Kanzaki & Murakami 2018
        ! therm = k_arrhenius(therm_ref,tc_ref+tempk_0,tc+tempk_0,ha,rg)
    ! case('hb')
        ! Diopside  + 4 H+  = Ca++  + 2 H2O  + Mg++  + 2 SiO2(aq)
        ! therm_ref = 10d0**(20.20981116d0)
        ! ha = -128.5d0
        ! tc_ref = 15d0
        ! from Kanzaki & Murakami 2018
        ! therm = k_arrhenius(therm_ref,tc_ref+tempk_0,tc+tempk_0,ha,rg)
    case('tm')
        ! Tremolite  + 14 H+  = 8 H2O  + 8 SiO2(aq)  + 2 Ca++  + 5 Mg++
        therm_ref = 10d0**(61.6715d0)
        ha = -429.0d0
        tc_ref = 15d0
        ! from Kanzaki & Murakami 2018
        therm = k_arrhenius(therm_ref,tc_ref+tempk_0,tc+tempk_0,ha,rg)
    case('antp')
        ! Anthophyllite (Mg2Mg5(Si8O22)(OH)2) + 14 H+  = 8 H2O  + 7 Mg++  + 8 SiO2(aq)
        therm_ref = 10d0**(70.83527792d0)
        ha = -508.6621624d0
        tc_ref = 15d0
        ! from Kanzaki & Murakami 2018
        therm = k_arrhenius(therm_ref,tc_ref+tempk_0,tc+tempk_0,ha,rg)
    case('gps')
        ! CaSO4*2H2O = Ca+2 + SO4-2 + 2H2O
        therm_ref = 10d0**(-4.61d0)
        ha = 1d0
        tc_ref = 25d0
        ! from minteq.v4
        therm = k_arrhenius(therm_ref,tc_ref+tempk_0,tc+tempk_0,ha,rg)
    case('la','ab','an','by','olg','and')
        ! CaxNa(1-x)Al(1+x)Si(3-x)O8 + (4x + 4) = xCa+2 + (1-x)Na+ + (1+x)Al+++ + (3-x)SiO2(aq) 
        ! obtaining Anorthite 
        therm_ref_1 = 10d0**28.8615308d0
        ha_1 = -292.8769275d0
        tc_ref_1 = 15d0
        ! from Kanzaki and Murakami 2018
        therm_1 = k_arrhenius(therm_ref_1,tc_ref_1+tempk_0,tc+tempk_0,ha_1,rg) ! rg in kJ mol^-1 K^-1
        delG_1 = - rg*(tc+tempk_0)*log(therm_1) ! del-G = -RT ln K  now in kJ mol-1
        ! Then albite 
        therm_ref_2 = 10d0**3.412182823d0
        ha_2 = -54.15042876d0
        tc_ref_2 = 15d0
        ! from Kanzaki and Murakami 2018
        therm_2 = k_arrhenius(therm_ref_2,tc_ref_2+tempk_0,tc+tempk_0,ha_2,rg)
        delG_2 = - rg*(tc+tempk_0)*log(therm_2) ! del-G = -RT ln K  now in kJ mol-1
        
        if (ss_x == 1d0) then 
            delG = delG_1 ! ideal anorthite
        elseif (ss_x == 0d0) then 
            delG = delG_2 ! ideal albite
        elseif (ss_x > 0d0 .and. ss_x < 1d0) then  ! solid solution 
            ! ideal(?) mixing (after Gislason and Arnorsson, 1993)
            delG = ss_x*delG_1 + (1d0-ss_x)*delG_2 + rg*(tc+tempk_0)*(ss_x*log(ss_x)+(1d0-ss_x)*log(1d0-ss_x))
        endif 
        therm = exp(-delG/(rg*(tc+tempk_0)))
    case('cpx','hb','dp')
        ! FexMg(1-x)CaSi2O6 + 4 H+  = Ca++  + 2 H2O  + xFe++ + (1-x)Mg++  + 2 SiO2(aq)
        ! obtaining hedenbergite 
        therm_ref_1 = 10d0**(20.20981116d0)
        ha_1 = -128.5d0
        tc_ref_1 = 15d0
        ! from Kanzaki & Murakami 2018
        therm_1 = k_arrhenius(therm_ref_1,tc_ref_1+tempk_0,tc+tempk_0,ha_1,rg) ! rg in kJ mol^-1 K^-1
        delG_1 = - rg*(tc+tempk_0)*log(therm_1) ! del-G = -RT ln K  now in kJ mol-1
        ! Then diopside 
        therm_ref_2 = 10d0**(21.79853309d0)
        ha_2 = -138.6020832d0
        tc_ref_2 = 15d0
        ! from Kanzaki and Murakami 2018
        therm_2 = k_arrhenius(therm_ref_2,tc_ref_2+tempk_0,tc+tempk_0,ha_2,rg)
        delG_2 = - rg*(tc+tempk_0)*log(therm_2) ! del-G = -RT ln K  now in kJ mol-1
        
        if (ss_x == 1d0) then 
            delG = delG_1 ! ideal hedenbergite
        elseif (ss_x == 0d0) then 
            delG = delG_2 ! ideal diopside
        elseif (ss_x > 0d0 .and. ss_x < 1d0) then  ! solid solution 
            ! ideal(?) mixing (after Gislason and Arnorsson, 1993)
            delG = ss_x*delG_1 + (1d0-ss_x)*delG_2 + rg*(tc+tempk_0)*(ss_x*log(ss_x)+(1d0-ss_x)*log(1d0-ss_x))
        endif 
        therm = exp(-delG/(rg*(tc+tempk_0)))
    case('opx','en','fer')
        ! FexMg(1-x)SiO3 + 2 H+  = xFe++ + (1-x)Mg++  +  SiO2(aq)
        ! obtaining ferrosilite
        therm_ref_1 = 10d0**(7.777162795d0)
        ha_1 = -60.08612326d0
        tc_ref_1 = 15d0
        ! from Kanzaki & Murakami 2018
        therm_1 = k_arrhenius(therm_ref_1,tc_ref_1+tempk_0,tc+tempk_0,ha_1,rg) ! rg in kJ mol^-1 K^-1
        delG_1 = - rg*(tc+tempk_0)*log(therm_1) ! del-G = -RT ln K  now in kJ mol-1
        ! Then enstatite 
        therm_ref_2 = 10d0**(11.99060855d0)
        ha_2 = -85.8218778d0
        tc_ref_2 = 15d0
        ! from Kanzaki and Murakami 2018
        therm_2 = k_arrhenius(therm_ref_2,tc_ref_2+tempk_0,tc+tempk_0,ha_2,rg)
        delG_2 = - rg*(tc+tempk_0)*log(therm_2) ! del-G = -RT ln K  now in kJ mol-1
        
        if (ss_x == 1d0) then 
            delG = delG_1 ! ideal ferrosilite
        elseif (ss_x == 0d0) then 
            delG = delG_2 ! ideal enstatite
        elseif (ss_x > 0d0 .and. ss_x < 1d0) then  ! solid solution 
            ! ideal(?) mixing (after Gislason and Arnorsson, 1993)
            delG = ss_x*delG_1 + (1d0-ss_x)*delG_2 + rg*(tc+tempk_0)*(ss_x*log(ss_x)+(1d0-ss_x)*log(1d0-ss_x))
        endif 
        therm = exp(-delG/(rg*(tc+tempk_0)))
    case('agt')
        ! obtaining opx (FexMg(1-x)SiO3 + 2 H+  = xFe++ + (1-x)Mg++  +  SiO2(aq))
        ! obtaining ferrosilite
        therm_ref_1 = 10d0**(7.777162795d0)
        ha_1 = -60.08612326d0
        tc_ref_1 = 15d0
        ! from Kanzaki & Murakami 2018
        therm_1 = k_arrhenius(therm_ref_1,tc_ref_1+tempk_0,tc+tempk_0,ha_1,rg) ! rg in kJ mol^-1 K^-1
        ! converting to the formula Fe2Si2O6 + 4 H+  = 2Fe++ + 2SiO2(aq)
        therm_1 = therm_1**2d0
        delG_1 = - rg*(tc+tempk_0)*log(therm_1) ! del-G = -RT ln K  now in kJ mol-1
        
        ! Then enstatite 
        therm_ref_2 = 10d0**(11.99060855d0)
        ha_2 = -85.8218778d0
        tc_ref_2 = 15d0
        ! from Kanzaki and Murakami 2018
        therm_2 = k_arrhenius(therm_ref_2,tc_ref_2+tempk_0,tc+tempk_0,ha_2,rg)
        ! converting to the formula Mg2Si2O6 + 4 H+  = 2Mg++ + 2SiO2(aq)
        therm_2 = therm_2**2d0
        delG_2 = - rg*(tc+tempk_0)*log(therm_2) ! del-G = -RT ln K  now in kJ mol-1
        
        if (ss_x == 1d0) then 
            delG_3 = delG_1 ! ideal ferrosilite
        elseif (ss_x == 0d0) then 
            delG_3 = delG_2 ! ideal enstatite
        elseif (ss_x > 0d0 .and. ss_x < 1d0) then  ! solid solution 
            ! ideal(?) mixing (after Gislason and Arnorsson, 1993)
            delG_3 = ss_x*delG_1 + (1d0-ss_x)*delG_2 + rg*(tc+tempk_0)*(ss_x*log(ss_x)+(1d0-ss_x)*log(1d0-ss_x))
        endif 
        therm_3 = exp(-delG_3/(rg*(tc+tempk_0)))
        
        ! obtaining cpx (FexMg(1-x)CaSi2O6 + 4 H+  = Ca++  + 2 H2O  + xFe++ + (1-x)Mg++  + 2 SiO2(aq))
        ! obtaining hedenbergite 
        therm_ref_4 = 10d0**(20.20981116d0)
        ha_4 = -128.5d0
        tc_ref_4 = 15d0
        ! from Kanzaki & Murakami 2018
        therm_4 = k_arrhenius(therm_ref_4,tc_ref_4+tempk_0,tc+tempk_0,ha_4,rg) ! rg in kJ mol^-1 K^-1
        delG_4 = - rg*(tc+tempk_0)*log(therm_4) ! del-G = -RT ln K  now in kJ mol-1
        ! Then diopside 
        therm_ref_5 = 10d0**(21.79853309d0)
        ha_5 = -138.6020832d0
        tc_ref_5 = 15d0
        ! from Kanzaki and Murakami 2018
        therm_5 = k_arrhenius(therm_ref_5,tc_ref_5+tempk_0,tc+tempk_0,ha_5,rg)
        delG_5 = - rg*(tc+tempk_0)*log(therm_5) ! del-G = -RT ln K  now in kJ mol-1
        
        if (ss_x == 1d0) then 
            delG_6 = delG_4 ! ideal hedenbergite
        elseif (ss_x == 0d0) then 
            delG_6 = delG_5 ! ideal diopside
        elseif (ss_x > 0d0 .and. ss_x < 1d0) then  ! solid solution 
            ! ideal(?) mixing (after Gislason and Arnorsson, 1993)
            delG_6 = ss_x*delG_4 + (1d0-ss_x)*delG_5 + rg*(tc+tempk_0)*(ss_x*log(ss_x)+(1d0-ss_x)*log(1d0-ss_x))
        endif 
        therm_6 = exp(-delG_6/(rg*(tc+tempk_0)))
        
        ! finally mixing opx and cpx 
        if (ss_y == 1d0) then 
            delG = delG_3 ! ideal opx
        elseif (ss_y == 0d0) then 
            delG = delG_6 ! ideal cpx
        elseif (ss_y > 0d0 .and. ss_y < 1d0) then  ! solid solution 
            ! ideal(?) mixing (after Gislason and Arnorsson, 1993)
            delG = ss_y*delG_3 + (1d0-ss_y)*delG_6 + rg*(tc+tempk_0)*(ss_y*log(ss_y)+(1d0-ss_y)*log(1d0-ss_y))
        endif 
        therm = exp(-delG/(rg*(tc+tempk_0)))
        
    case('g1')
        therm = 0.121d0 ! mo2 Michaelis, Davidson et al. (2012)
    case('g2')
        therm = 0.121d0 ! mo2 Michaelis, Davidson et al. (2012)
        ! therm = 0.121d-1 ! mo2 Michaelis, Davidson et al. (2012) x 0.1
        ! therm = 0.121d-2 ! mo2 Michaelis, Davidson et al. (2012) x 0.01
        ! therm = 0.121d-3 ! mo2 Michaelis, Davidson et al. (2012) x 0.001
        ! therm = 0.121d-6 ! mo2 Michaelis, Davidson et al. (2012) x 1e-6
    case('g3')
        therm = 0.121d0 ! mo2 Michaelis, Davidson et al. (2012)
    case default 
        therm = 0d0
endselect 

endsubroutine sld_therm

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine precalc_gases( &
    & nz,dt,ucv,dz,poro,sat,torg,tora,v,prox &! input 
    & ,nsp_gas,nsp_gas_all,chrgas,chrgas_all,keqgas_h,mgasi,mgasth,mgas &! input
    & ,nrxn_ext,chrrxn_ext,rxnext,dgasa,dgasg,stgas_ext &! input
    & ,mgasx &! output 
    & )
implicit none 
integer,intent(in)::nz
real(kind=8),intent(in)::dt,ucv
real(kind=8)::pco2th,pco2i,kco2,k1,k2,kho
real(kind=8),dimension(nz),intent(in)::poro,sat,torg,tora,v,dz,prox
real(kind=8),dimension(nz)::khco2,pco2,resp,pco2x

integer iz,ispg,irxn
real(kind=8) pco2tmp,edifi,ediftmp
real(kind=8),dimension(nz)::alpha,edif

integer,intent(in)::nsp_gas,nsp_gas_all,nrxn_ext
character(5),dimension(nsp_gas),intent(in)::chrgas
character(5),dimension(nsp_gas_all),intent(in)::chrgas_all
character(5),dimension(nrxn_ext),intent(in)::chrrxn_ext
real(kind=8),dimension(nsp_gas_all,3),intent(in)::keqgas_h
real(kind=8),dimension(nsp_gas),intent(in)::mgasi,mgasth,dgasa,dgasg
real(kind=8),dimension(nsp_gas,nz),intent(in)::mgas
real(kind=8),dimension(nrxn_ext,nz),intent(in)::rxnext
real(kind=8),dimension(nrxn_ext,nsp_gas),intent(in)::stgas_ext
real(kind=8),dimension(nsp_gas,nz),intent(inout)::mgasx



integer ieqgas_h0,ieqgas_h1,ieqgas_h2
data ieqgas_h0,ieqgas_h1,ieqgas_h2/1,2,3/

if (nsp_gas == 0) return

kco2 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h0)
k1 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h1)
k2 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h2)

khco2 = kco2*(1d0+k1/prox + k1*k2/prox/prox)

kho = keqgas_h(findloc(chrgas_all,'po2',dim=1),ieqgas_h0)

do ispg = 1, nsp_gas

    select case(trim(adjustl(chrgas(ispg))))
        case('pco2')
            alpha = ucv*poro*(1.0d0-sat)*1d3+poro*sat*khco2*1d3
            ! if (any(chrrxn_ext=='resp')) then 
                ! resp = rxnext(findloc(chrrxn_ext,'resp',dim=1),:)
            ! else 
                ! resp = 0d0
            ! endif 
        case('po2')
            alpha = ucv*poro*(1.0d0-sat)*1d3+poro*sat*kho*1d3
            ! resp = 0d0
    endselect 
    
    resp = 0d0
    do irxn = 1, nrxn_ext
        if (stgas_ext(irxn,ispg)>0d0) then 
            resp = resp + stgas_ext(irxn,ispg)*rxnext(irxn,:)
        endif 
    enddo 
    
    edif = ucv*poro*(1.0d0-sat)*1d3*torg*dgasg(ispg) +poro*sat*khco2*1d3*tora*dgasa(ispg)
    edifi = edif(1)
    edifi = ucv*1d3*dgasg(ispg) 

    pco2x = mgasx(ispg,:)
    pco2 = mgas(ispg,:)
    
    pco2i = mgasi(ispg)
    pco2th = mgasth(ispg)
    
    do iz = 1, nz

        ! if (pco2x(iz)>=pco2th) cycle

        pco2tmp = pco2(max(1,iz-1))
        ediftmp = edif(max(1,iz-1))
        if (iz==1) pco2tmp = pco2i
        if (iz==1) ediftmp = edifi

        pco2x(iz) = max(0.0d0 &
            & ,dt/alpha(iz)* &
            & ( &
            & alpha(iz)*pco2(iz)/dt &
            & +(0.5d0*(edif(iz)+edif(min(nz,iz+1)))*(pco2(min(nz,iz+1))-pco2(iz))/(0.5d0*(dz(iz)+dz(min(nz,iz+1)))) &
            & - 0.5d0*(edif(iz)+ediftmp)*(pco2(iz)-pco2tmp)/(0.5d0*(dz(iz)+dz(max(1,iz-1)))))/dz(iz) &
            & - poro(iz)*sat(iz)*v(iz)*khco2(iz)*1d3*(pco2(iz)-pco2tmp)/dz(iz)  &
            & + resp(iz) & 
            & ) &
            & )

    end do 
    
    mgasx(ispg,:) = pco2x
    
enddo

endsubroutine precalc_gases

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine precalc_gases_v2( &
    & nz,dt,ucv,dz,poro,sat,torg,tora,v,prox,hr &! input 
    & ,nsp_gas,nsp_gas_all,chrgas,chrgas_all,keqgas_h,mgasi,mgasth,mgas &! input
    & ,nrxn_ext,chrrxn_ext,rxnext,dgasa,dgasg,stgas_ext &! input
    & ,nsp_sld,stgas,mv,ksld,msld,omega,nonprec &! input
    & ,mgasx &! output 
    & )
implicit none 
integer,intent(in)::nz
real(kind=8),intent(in)::dt,ucv
real(kind=8)::pco2th,pco2i,kco2,k1,k2,kho
real(kind=8),dimension(nz),intent(in)::poro,sat,torg,tora,v,dz,prox,hr
real(kind=8),dimension(nz)::khco2,pco2,resp,pco2x

integer iz,ispg,irxn,isps
real(kind=8) pco2tmp,edifi,ediftmp
real(kind=8),dimension(nz)::alpha,edif

integer,intent(in)::nsp_gas,nsp_gas_all,nrxn_ext
character(5),dimension(nsp_gas),intent(in)::chrgas
character(5),dimension(nsp_gas_all),intent(in)::chrgas_all
character(5),dimension(nrxn_ext),intent(in)::chrrxn_ext
real(kind=8),dimension(nsp_gas_all,3),intent(in)::keqgas_h
real(kind=8),dimension(nsp_gas),intent(in)::mgasi,mgasth,dgasa,dgasg
real(kind=8),dimension(nsp_gas,nz),intent(in)::mgas
real(kind=8),dimension(nrxn_ext,nz),intent(in)::rxnext
real(kind=8),dimension(nrxn_ext,nsp_gas),intent(in)::stgas_ext
real(kind=8),dimension(nsp_gas,nz),intent(inout)::mgasx

integer,intent(in)::nsp_sld
real(kind=8),dimension(nsp_sld),intent(in)::mv
real(kind=8),dimension(nsp_sld,nz),intent(in)::ksld,msld,omega,nonprec
real(kind=8),dimension(nsp_sld,nsp_gas),intent(in)::stgas

integer ieqgas_h0,ieqgas_h1,ieqgas_h2
data ieqgas_h0,ieqgas_h1,ieqgas_h2/1,2,3/

if (nsp_gas == 0) return

kco2 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h0)
k1 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h1)
k2 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h2)

khco2 = kco2*(1d0+k1/prox + k1*k2/prox/prox)

kho = keqgas_h(findloc(chrgas_all,'po2',dim=1),ieqgas_h0)

do ispg = 1, nsp_gas

    select case(trim(adjustl(chrgas(ispg))))
        case('pco2')
            alpha = ucv*poro*(1.0d0-sat)*1d3+poro*sat*khco2*1d3
            ! if (any(chrrxn_ext=='resp')) then 
                ! resp = rxnext(findloc(chrrxn_ext,'resp',dim=1),:)
            ! else 
                ! resp = 0d0
            ! endif 
        case('po2')
            alpha = ucv*poro*(1.0d0-sat)*1d3+poro*sat*kho*1d3
            ! resp = 0d0
    endselect 
    
    resp = 0d0
    do irxn = 1, nrxn_ext
        resp = resp + stgas_ext(irxn,ispg)*rxnext(irxn,:)
    enddo 
    
    do isps = 1,nsp_sld
        resp = resp + ( &
            & stgas(isps,ispg)*ksld(isps,:)*poro*hr*mv(isps)*1d-6*msld(isps,:)*(1d0-omega(isps,:)) &
            & *merge(0d0,1d0,1d0-omega(isps,:)*nonprec(isps,:) < 0d0) &
            & )
    enddo 
    
    edif = ucv*poro*(1.0d0-sat)*1d3*torg*dgasg(ispg) +poro*sat*khco2*1d3*tora*dgasa(ispg)
    edifi = edif(1)
    edifi = ucv*1d3*dgasg(ispg) 

    pco2x = mgasx(ispg,:)
    pco2 = mgas(ispg,:)
    
    pco2i = mgasi(ispg)
    pco2th = mgasth(ispg)
    
    do iz = 1, nz

        ! if (pco2x(iz)>=pco2th) cycle

        pco2tmp = pco2(max(1,iz-1))
        ediftmp = edif(max(1,iz-1))
        if (iz==1) pco2tmp = pco2i
        if (iz==1) ediftmp = edifi

        pco2x(iz) = max(pco2th*0.1d0 &
            & ,dt/alpha(iz)* &
            & ( &
            & alpha(iz)*pco2(iz)/dt &
            & +(0.5d0*(edif(iz)+edif(min(nz,iz+1)))*(pco2(min(nz,iz+1))-pco2(iz))/(0.5d0*(dz(iz)+dz(min(nz,iz+1)))) &
            & - 0.5d0*(edif(iz)+ediftmp)*(pco2(iz)-pco2tmp)/(0.5d0*(dz(iz)+dz(max(1,iz-1)))))/dz(iz) &
            & - poro(iz)*sat(iz)*v(iz)*khco2(iz)*1d3*(pco2(iz)-pco2tmp)/dz(iz)  &
            & + resp(iz) & 
            & ) &
            & )

    end do 
    
    mgasx(ispg,:) = pco2x
    
enddo

endsubroutine precalc_gases_v2

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine precalc_slds_v2( &
    & nz,dt,w,dz,poro,hr,sat &! input
    & ,nsp_sld,nsp_sld_2,chrsld,chrsld_2,msldth,msldi,mv,msld,msldsupp,ksld,omega &! input
    & ,nrxn_ext,rxnext,stsld_ext &!input
    & ,msldx &! output
    & )
implicit none

integer,intent(in)::nz
real(kind=8),intent(in)::dt,w
real(kind=8)::mfoi,mfoth
real(kind=8),dimension(nz),intent(in)::dz,poro,hr,sat
real(kind=8),dimension(nz)::mfo,mfosupp,mfox,rxn_tmp

integer iz,isps,irxn

integer,intent(in)::nsp_sld,nsp_sld_2
character(5),dimension(nsp_sld),intent(in)::chrsld
character(5),dimension(nsp_sld_2),intent(in)::chrsld_2
real(kind=8),dimension(nsp_sld),intent(in)::msldth,msldi,mv
real(kind=8),dimension(nsp_sld,nz),intent(in)::msld,msldsupp,ksld,omega
real(kind=8),dimension(nsp_sld,nz),intent(inout)::msldx

integer,intent(in)::nrxn_ext
real(kind=8),dimension(nrxn_ext,nz),intent(in)::rxnext
real(kind=8),dimension(nrxn_ext,nsp_sld),intent(in)::stsld_ext

if (nsp_sld == 0) return

do isps = 1,nsp_sld

    mfox = msldx(isps,:)
    mfo = msld(isps,:)
    mfoth = msldth(isps)
    mfoi = msldi(isps)
    mfosupp = msldsupp(isps,:)
    
    rxn_tmp = 0d0
    do irxn = 1, nrxn_ext
        if (stsld_ext(irxn,isps)>0d0) then 
            rxn_tmp = rxn_tmp + stsld_ext(irxn,isps)*rxnext(irxn,:)
        endif  
    enddo 
    
    if (any(chrsld_2 ==chrsld(isps))) then 
        do iz = 1, nz
            if (mfox(iz)>=mfoth) cycle

            if (iz/=nz) then 
                mfox(iz) = max(0d0, &
                    & mfo(iz) +dt*(w*(mfo(iz+1)-mfo(iz))/dz(iz) + mfosupp(iz)) &
                    & +ksld(isps,iz)*poro(iz)*hr(iz)*mv(isps)*1d-6*mfox(iz)*(omega(isps,iz) - 1d0) &
                    & *merge(1d0,0d0,omega(isps,iz) - 1d0 > 0d0) &
                    & +rxn_tmp(iz) &
                    & )
            else 
                mfox(iz) = max(0d0, &
                    & mfo(iz) + dt*(w*(mfoi-mfo(iz))/dz(iz)+ mfosupp(iz)) &
                    & +ksld(isps,iz)*poro(iz)*hr(iz)*mv(isps)*1d-6*mfox(iz)*(omega(isps,iz) - 1d0) &
                    & *merge(1d0,0d0,omega(isps,iz) - 1d0 > 0d0) &
                    & +rxn_tmp(iz) &
                    & )
            endif 
        enddo
    else
        do iz = 1, nz
            if (mfox(iz)>=mfoth) cycle

            if (iz/=nz) then 
                mfox(iz) = max(0d0, &
                    & mfo(iz) +dt*(w*(mfo(iz+1)-mfo(iz))/dz(iz) + mfosupp(iz)) &
                    & +rxn_tmp(iz) &
                    & )
            else 
                mfox(iz) = max(0d0, &
                    & mfo(iz) + dt*(w*(mfoi-mfo(iz))/dz(iz)+ mfosupp(iz)) &
                    & +rxn_tmp(iz) &
                    & )
            endif 
        enddo
    endif 
    
    msldx(isps,:) = mfox
    
enddo 

endsubroutine precalc_slds_v2

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine precalc_slds_v2_1( &
    & nz,dt,w,dz,poro,hr,sat &! input
    & ,nsp_sld,nsp_sld_2,chrsld,chrsld_2,msldth,msldi,mv,msld,msldsupp,ksld,omega &! input
    & ,nrxn_ext,rxnext,stsld_ext &!input
    & ,labs,turbo2,trans &! input
    & ,msldx &! output
    & )
implicit none

integer,intent(in)::nz
real(kind=8),intent(in)::dt,w
real(kind=8)::mfoi,mfoth
real(kind=8),dimension(nz),intent(in)::dz,poro,hr,sat
real(kind=8),dimension(nz)::mfo,mfosupp,mfox,rxn_tmp

integer iz,isps,irxn,iiz

integer,intent(in)::nsp_sld,nsp_sld_2
character(5),dimension(nsp_sld),intent(in)::chrsld
character(5),dimension(nsp_sld_2),intent(in)::chrsld_2
real(kind=8),dimension(nsp_sld),intent(in)::msldth,msldi,mv
real(kind=8),dimension(nsp_sld,nz),intent(in)::msld,msldsupp,ksld,omega
real(kind=8),dimension(nsp_sld,nz),intent(inout)::msldx

integer,intent(in)::nrxn_ext
real(kind=8),dimension(nrxn_ext,nz),intent(in)::rxnext
real(kind=8),dimension(nrxn_ext,nsp_sld),intent(in)::stsld_ext

logical,dimension(nsp_sld),intent(in)::labs,turbo2
real(kind=8),dimension(nz,nz,nsp_sld),intent(in)::trans

real(kind=8) trans_tmp(nz)

if (nsp_sld == 0) return

do isps = 1,nsp_sld

    mfox = msldx(isps,:)
    mfo = msld(isps,:)
    mfoth = msldth(isps)
    mfoi = msldi(isps)
    mfosupp = msldsupp(isps,:)
    
    rxn_tmp = 0d0
    do irxn = 1, nrxn_ext
        if (stsld_ext(irxn,isps)>0d0) then 
            rxn_tmp = rxn_tmp + stsld_ext(irxn,isps)*rxnext(irxn,:)
        endif  
    enddo 
    
    trans_tmp = 0d0
    do iz=1,nz
        do iiz=1,nz
            if (turbo2(isps) .or. labs(isps)) then 
                if (trans(iiz,iz,isps) >0d0) then 
                    trans_tmp(iz) = trans_tmp(iz)+ trans(iiz,iz,isps)/dz(iz)*dz(iiz)*mfo(iiz)
                endif 
            else
                if (trans(iiz,iz,isps) >0d0) then 
                    trans_tmp(iz) = trans_tmp(iz) + trans(iiz,iz,isps)/dz(iz)*mfo(iiz)
                endif 
            endif 
        enddo 
    enddo 
    
    if (any(chrsld_2 ==chrsld(isps))) then 
        do iz = 1, nz
            if (mfox(iz)>=mfoth) cycle

            if (iz/=nz) then 
                mfox(iz) = max(0d0, &
                    & mfo(iz) +dt*(w*(mfo(iz+1)-mfo(iz))/dz(iz) + mfosupp(iz)) &
                    & +ksld(isps,iz)*poro(iz)*hr(iz)*mv(isps)*1d-6*mfox(iz)*(omega(isps,iz) - 1d0) &
                    & *merge(1d0,0d0,omega(isps,iz) - 1d0 > 0d0) &
                    & +rxn_tmp(iz) &
                    & + trans_tmp(iz) &
                    & )
            else 
                mfox(iz) = max(0d0, &
                    & mfo(iz) + dt*(w*(mfoi-mfo(iz))/dz(iz)+ mfosupp(iz)) &
                    & +ksld(isps,iz)*poro(iz)*hr(iz)*mv(isps)*1d-6*mfox(iz)*(omega(isps,iz) - 1d0) &
                    & *merge(1d0,0d0,omega(isps,iz) - 1d0 > 0d0) &
                    & +rxn_tmp(iz) &
                    & + trans_tmp(iz) &
                    & )
            endif 
        enddo
    else
        do iz = 1, nz
            if (mfox(iz)>=mfoth) cycle

            if (iz/=nz) then 
                mfox(iz) = max(0d0, &
                    & mfo(iz) +dt*(w*(mfo(iz+1)-mfo(iz))/dz(iz) + mfosupp(iz)) &
                    & +rxn_tmp(iz) &
                    & + trans_tmp(iz) &
                    & )
            else 
                mfox(iz) = max(0d0, &
                    & mfo(iz) + dt*(w*(mfoi-mfo(iz))/dz(iz)+ mfosupp(iz)) &
                    & +rxn_tmp(iz) &
                    & + trans_tmp(iz) &
                    & )
            endif 
        enddo
    endif 
    
    msldx(isps,:) = mfox
    
enddo 

endsubroutine precalc_slds_v2_1

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine precalc_slds_v3( &
    & nz,dt,w,dz,poro,hr,sat &! input
    & ,nsp_sld,msldth,msldi,mv,msld,msldsupp,ksld,omega,nonprec &! input
    & ,msldx &! output
    & )
implicit none

integer,intent(in)::nz
real(kind=8),intent(in)::dt,w
real(kind=8)::mfoi,mfoth
real(kind=8),dimension(nz),intent(in)::dz,poro,hr,sat
real(kind=8),dimension(nz)::mfo,mfosupp,mfox

integer iz,isps

integer,intent(in)::nsp_sld
real(kind=8),dimension(nsp_sld),intent(in)::msldth,msldi,mv
real(kind=8),dimension(nsp_sld,nz),intent(in)::msld,msldsupp,ksld,omega,nonprec
real(kind=8),dimension(nsp_sld,nz),intent(inout)::msldx

if (nsp_sld == 0) return

do isps = 1,nsp_sld

    mfox = msldx(isps,:)
    mfo = msld(isps,:)
    mfoth = msldth(isps)
    mfoi = msldi(isps)
    mfosupp = msldsupp(isps,:)
    
    do iz = 1, nz
        ! if (mfox(iz)>=mfoth) cycle

        if (iz/=nz) then 
            mfox(iz) = max(mfoth*0.1d0, &
                & mfo(iz) +dt*(w*(mfo(iz+1)-mfo(iz))/dz(iz) + mfosupp(iz)) &
                & -ksld(isps,iz)*poro(iz)*hr(iz)*mv(isps)*1d-6*mfox(iz)*(1d0-omega(isps,iz)) &
                & *merge(0d0,1d0,1d0-omega(isps,iz)*nonprec(isps,iz) < 0d0) &
                & )
        else 
            mfox(iz) = max(mfoth*0.1d0, &
                & mfo(iz) + dt*(w*(mfoi-mfo(iz))/dz(iz)+ mfosupp(iz)) &
                & -ksld(isps,iz)*poro(iz)*hr(iz)*mv(isps)*1d-6*mfox(iz)*(1d0-omega(isps,iz)) &
                & *merge(0d0,1d0,1d0-omega(isps,iz)*nonprec(isps,iz) < 0d0) &
                & )
        endif 
    enddo
    
    msldx(isps,:) = mfox
    
enddo 

endsubroutine precalc_slds_v3

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine precalc_slds_v3_1( &
    & nz,dt,w,dz,poro,hr,sat &! input
    & ,nsp_sld,msldth,msldi,mv,msld,msldsupp,ksld,omega,nonprec &! input
    & ,labs,turbo2,trans &! input
    & ,msldx &! output
    & )
implicit none

integer,intent(in)::nz
real(kind=8),intent(in)::dt,w
real(kind=8)::mfoi,mfoth
real(kind=8),dimension(nz),intent(in)::dz,poro,hr,sat
real(kind=8),dimension(nz)::mfo,mfosupp,mfox

integer iz,isps,iiz

integer,intent(in)::nsp_sld
real(kind=8),dimension(nsp_sld),intent(in)::msldth,msldi,mv
real(kind=8),dimension(nsp_sld,nz),intent(in)::msld,msldsupp,ksld,omega,nonprec
real(kind=8),dimension(nsp_sld,nz),intent(inout)::msldx
logical,dimension(nsp_sld)::labs,turbo2
real(kind=8),dimension(nz,nz,nsp_sld)::trans

real(kind=8) swnonloc

if (nsp_sld == 0) return

do isps = 1,nsp_sld

    mfox = msldx(isps,:)
    mfo = msld(isps,:)
    mfoth = msldth(isps)
    mfoi = msldi(isps)
    mfosupp = msldsupp(isps,:)
    
    swnonloc = 0d0
    if (turbo2(isps).or.labs(isps)) swnonloc = 1d0
    
    do iz = 1, nz
        ! if (mfox(iz)>=mfoth) cycle

        if (iz/=nz) then 
            mfox(iz) = max(mfoth*0.1d0, &
                & mfo(iz) +dt*(w*(mfo(iz+1)-mfo(iz))/dz(iz) + mfosupp(iz)) &
                & -ksld(isps,iz)*poro(iz)*hr(iz)*mv(isps)*1d-6*mfox(iz)*(1d0-omega(isps,iz)) &
                & *merge(0d0,1d0,1d0-omega(isps,iz)*nonprec(isps,iz) < 0d0) &
                & - sum(trans(:,iz,isps)/dz(iz)*mfo(:))*(1d0-swnonloc) &
                & - sum(trans(:,iz,isps)/dz(iz)*dz*mfo(:))*swnonloc &
                & )
        else 
            mfox(iz) = max(mfoth*0.1d0, &
                & mfo(iz) + dt*(w*(mfoi-mfo(iz))/dz(iz)+ mfosupp(iz)) &
                & -ksld(isps,iz)*poro(iz)*hr(iz)*mv(isps)*1d-6*mfox(iz)*(1d0-omega(isps,iz)) &
                & *merge(0d0,1d0,1d0-omega(isps,iz)*nonprec(isps,iz) < 0d0) &
                & - sum(trans(:,iz,isps)/dz(iz)*mfo(:))*(1d0-swnonloc) &
                & - sum(trans(:,iz,isps)/dz(iz)*dz*mfo(:))*swnonloc &
                & )
        endif 
    enddo
    
    msldx(isps,:) = mfox
    
enddo 

endsubroutine precalc_slds_v3_1

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine precalc_aqs( &
    & nz,dt,v,dz,tora,poro,sat,hr &! input 
    & ,nsp_aq,nsp_sld,daq,maqth,maqi,maq,mv,msldx,ksld,staq &! input
    & ,nrxn_ext,staq_ext,rxnext &! input
    & ,maqx &! output
    & )
implicit none

integer,intent(in)::nz
real(kind=8),intent(in)::dt
real(kind=8)::nath,dna,nai,rxn_tmp
real(kind=8),dimension(nz),intent(in)::v,tora,poro,sat,hr,dz
real(kind=8),dimension(nz)::na,nax

integer iz,ispa,isps,irxn
real(kind=8) ctmp,edifi,ediftmp
real(kind=8),dimension(nz)::edif

integer,intent(in)::nsp_aq,nsp_sld,nrxn_ext
real(kind=8),dimension(nsp_aq),intent(in)::daq,maqth,maqi
real(kind=8),dimension(nsp_aq,nz),intent(in)::maq
real(kind=8),dimension(nsp_sld),intent(in)::mv
real(kind=8),dimension(nsp_sld,nz),intent(in)::msldx,ksld
real(kind=8),dimension(nsp_sld,nsp_aq),intent(in)::staq
real(kind=8),dimension(nsp_aq,nz),intent(inout)::maqx
real(kind=8),dimension(nrxn_ext,nz),intent(in)::rxnext
real(kind=8),dimension(nrxn_ext,nsp_aq),intent(in)::staq_ext

if (nsp_aq == 0 ) return

do ispa = 1, nsp_aq

    dna = daq(ispa)
    nath = maqth(ispa)
    nai = maqi(ispa)
    
    na = maq(ispa,:)
    nax = maqx(ispa,:)

    edif = poro*sat*1d3*dna*tora
    edifi = edif(1)

    do iz = 1, nz

        if (nax(iz)>=nath) cycle

        ctmp = na(max(1,iz-1))
        ediftmp = edif(max(1,iz-1))
        if (iz==1) ctmp = nai
        if (iz==1) ediftmp = edifi
    
        rxn_tmp = 0d0
        
        do isps = 1, nsp_sld
            if (staq(isps,ispa)>0d0) then 
                rxn_tmp = rxn_tmp  &
                    & + staq(isps,ispa)*ksld(isps,iz)*poro(iz)*hr(iz)*mv(isps)*1d-6*msldx(isps,iz)
            endif 
        enddo 
        
        do irxn = 1, nrxn_ext
            if (staq(irxn,ispa)>0d0) then 
                rxn_tmp = rxn_tmp  &
                    & + staq_ext(irxn,ispa)*rxnext(irxn,iz)
            endif 
        enddo 
        
        nax(iz) = max(0.0d0, &
            & na(iz) +dt/(poro(iz)*sat(iz)*1d3)*( &
            & -poro(iz)*sat(iz)*1d3*v(iz)*(na(iz)-ctmp)/dz(iz) &
            & +(0.5d0*(edif(iz)+edif(min(nz,iz+1)))*(na(min(nz,iz+1))-na(iz))/(0.5d0*(dz(iz)+dz(min(nz,iz+1)))) &
            & - 0.5d0*(edif(iz)+ediftmp)*(na(iz)-ctmp)/(0.5d0*(dz(iz)+dz(max(1,iz-1)))))/dz(iz) &
            & +rxn_tmp &
            & ) &
            & )
            
    enddo
    
    maqx(ispa,:) = nax 

enddo 

endsubroutine precalc_aqs

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine precalc_aqs_v2( &
    & nz,dt,v,dz,tora,poro,sat,hr &! input 
    & ,nsp_aq,nsp_sld,daq,maqth,maqi,maq,mv,msldx,ksld,staq,omega,nonprec &! input
    & ,nrxn_ext,staq_ext,rxnext &! input
    & ,maqx &! output
    & )
implicit none

integer,intent(in)::nz
real(kind=8),intent(in)::dt
real(kind=8)::nath,dna,nai,rxn_tmp
real(kind=8),dimension(nz),intent(in)::v,tora,poro,sat,hr,dz
real(kind=8),dimension(nz)::na,nax

integer iz,ispa,isps,irxn
real(kind=8) ctmp,edifi,ediftmp
real(kind=8),dimension(nz)::edif

integer,intent(in)::nsp_aq,nsp_sld,nrxn_ext
real(kind=8),dimension(nsp_aq),intent(in)::daq,maqth,maqi
real(kind=8),dimension(nsp_aq,nz),intent(in)::maq
real(kind=8),dimension(nsp_sld),intent(in)::mv
real(kind=8),dimension(nsp_sld,nz),intent(in)::msldx,ksld,omega,nonprec
real(kind=8),dimension(nsp_sld,nsp_aq),intent(in)::staq
real(kind=8),dimension(nsp_aq,nz),intent(inout)::maqx
real(kind=8),dimension(nrxn_ext,nz),intent(in)::rxnext
real(kind=8),dimension(nrxn_ext,nsp_aq),intent(in)::staq_ext

if (nsp_aq == 0 ) return

do ispa = 1, nsp_aq

    dna = daq(ispa)
    nath = maqth(ispa)
    nai = maqi(ispa)
    
    na = maq(ispa,:)
    nax = maqx(ispa,:)

    edif = poro*sat*1d3*dna*tora
    edifi = edif(1)

    do iz = 1, nz

        ! if (nax(iz)>=nath) cycle

        ctmp = na(max(1,iz-1))
        ediftmp = edif(max(1,iz-1))
        if (iz==1) ctmp = nai
        if (iz==1) ediftmp = edifi
    
        rxn_tmp = 0d0
        
        do isps = 1, nsp_sld
            if (staq(isps,ispa)/=0d0) then 
                rxn_tmp = rxn_tmp  &
                    & + staq(isps,ispa)*ksld(isps,iz)*poro(iz)*hr(iz)*mv(isps)*1d-6*msldx(isps,iz)*(1d0-omega(isps,iz)) &
                    & *merge(0d0,1d0,1d0-omega(isps,iz)*nonprec(isps,iz) < 0d0) 
            endif 
        enddo 
        
        do irxn = 1, nrxn_ext
            if (staq(irxn,ispa)/=0d0) then 
                rxn_tmp = rxn_tmp  &
                    & + staq_ext(irxn,ispa)*rxnext(irxn,iz)
            endif 
        enddo 
        
        nax(iz) = max(nath*0.1d0, &
            & na(iz) +dt/(poro(iz)*sat(iz)*1d3)*( &
            & -poro(iz)*sat(iz)*1d3*v(iz)*(na(iz)-ctmp)/dz(iz) &
            & +(0.5d0*(edif(iz)+edif(min(nz,iz+1)))*(na(min(nz,iz+1))-na(iz))/(0.5d0*(dz(iz)+dz(min(nz,iz+1)))) &
            & - 0.5d0*(edif(iz)+ediftmp)*(na(iz)-ctmp)/(0.5d0*(dz(iz)+dz(max(1,iz-1)))))/dz(iz) &
            & +rxn_tmp &
            & ) &
            & )
            
    enddo
    
    maqx(ispa,:) = nax 

enddo 

endsubroutine precalc_aqs_v2

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine calc_pH_v5( &
    & nz,kw,nsp_aq,nsp_gas,nsp_aq_all,nsp_gas_all,nsp_aq_cnst,nsp_gas_cnst &! input 
    & ,chraq,chraq_cnst,chraq_all,chrgas,chrgas_cnst,chrgas_all &!input
    & ,maqx,maqc,mgasx,mgasc,keqgas_h,keqaq_h,keqaq_c,keqaq_s &! input
    & ,print_cb,print_loc,z &! input 
    & ,prox,ph_error &! output
    & ) 
! solving charge balance:
! [H+] + ZX[Xz+] - ZY[YZ-] - [HCO3-] - 2[CO32-] - [OH-] - [H3SiO4-] - 2[H2SiO42-] = 0
! [H+] + ZX[Xz+] - ZY[YZ-] - k1kco2pCO2/[H+] - 2k2k1kco2pCO2/[H+]^2 - kw/[H+] - [Si]/([H+]/k1si + 1 + k2si/k1si/[H+])
!       - 2[Si]/([H+]^2/k2si + [H+]k1si/k2si + 1) = 0
! [H+]^3 + (ZX[Xz+] - ZY[YZ-])[H+]^2 - (k1kco2pCO2+kw)[H+] - 2k2k1kco2pCO2  = 0
! NetCat is defined as (ZX[Xz+] - ZY[YZ-])
! [H+]^3 + NetCat[H+]^2 - (k1kco2pCO2+kw)[H+] - 2k2k1kco2pCO2  = 0
implicit none
integer,intent(in)::nz
real(kind=8),intent(in)::kw
real(kind=8) kco2,k1,k2,k1si,k2si,k1mg,k1mgco3,k1mghco3,k1ca,k1caco3,k1cahco3,k1al,k2al,k3al,k4al &
    & ,k1fe2,k1fe2co3,k1fe2hco3,k1fe3,k2fe3,k3fe3,k4fe3,k1naco3,k1nahco3,k1so4,k1kso4,k1naso4  &
    & ,k1caso4,k1mgso4,k1fe2so4,k1also4,k1also42,k1fe3so4,k1fe3so42
real(kind=8),dimension(nz)::nax,mgx,cax,so4x,pco2x,six,alx,fe2x,fe3x,kx,so4f
real(kind=8),dimension(nz),intent(in)::z
real(kind=8),dimension(nz),intent(inout)::prox
logical,intent(out)::ph_error

real(kind=8),dimension(nz)::df,f,netcat
real(kind=8) error,tol
integer iter,iz

integer,intent(in)::nsp_aq,nsp_gas,nsp_aq_all,nsp_gas_all,nsp_aq_cnst,nsp_gas_cnst
character(5),dimension(nsp_aq),intent(in)::chraq
character(5),dimension(nsp_aq_cnst),intent(in)::chraq_cnst
character(5),dimension(nsp_aq_all),intent(in)::chraq_all
character(5),dimension(nsp_gas),intent(in)::chrgas
character(5),dimension(nsp_gas_cnst),intent(in)::chrgas_cnst
character(5),dimension(nsp_gas_all),intent(in)::chrgas_all
real(kind=8),dimension(nsp_aq,nz),intent(in)::maqx
real(kind=8),dimension(nsp_aq_cnst,nz),intent(in)::maqc
real(kind=8),dimension(nsp_gas,nz),intent(in)::mgasx
real(kind=8),dimension(nsp_gas_cnst,nz),intent(in)::mgasc
real(kind=8),dimension(nsp_gas_all,3),intent(in)::keqgas_h
real(kind=8),dimension(nsp_aq_all,4),intent(in)::keqaq_h
real(kind=8),dimension(nsp_aq_all,2),intent(in)::keqaq_c
real(kind=8),dimension(nsp_aq_all,2),intent(in)::keqaq_s

integer ieqgas_h0,ieqgas_h1,ieqgas_h2
data ieqgas_h0,ieqgas_h1,ieqgas_h2/1,2,3/

integer ieqaq_h1,ieqaq_h2,ieqaq_h3,ieqaq_h4
data ieqaq_h1,ieqaq_h2,ieqaq_h3,ieqaq_h4/1,2,3,4/

integer ieqaq_co3,ieqaq_hco3
data ieqaq_co3,ieqaq_hco3/1,2/

integer ieqaq_so4,ieqaq_so42
data ieqaq_so4,ieqaq_so42/1,2/

logical,intent(in)::print_cb
character(500),intent(in)::print_loc
logical so4_error

error = 1d4
tol = 1d-6

prox = 1d0 
iter = 0


kco2 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h0)
k1 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h1)
k2 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h2)
k1si = keqaq_h(findloc(chraq_all,'si',dim=1),ieqaq_h1)
k2si = keqaq_h(findloc(chraq_all,'si',dim=1),ieqaq_h2)
k1mg = keqaq_h(findloc(chraq_all,'mg',dim=1),ieqaq_h1)
k1mgco3 = keqaq_c(findloc(chraq_all,'mg',dim=1),ieqaq_co3)
k1mghco3  = keqaq_c(findloc(chraq_all,'mg',dim=1),ieqaq_hco3)
k1ca = keqaq_h(findloc(chraq_all,'ca',dim=1),ieqaq_h1)
k1caco3 = keqaq_c(findloc(chraq_all,'ca',dim=1),ieqaq_co3)
k1cahco3 = keqaq_c(findloc(chraq_all,'ca',dim=1),ieqaq_hco3)
k1al= keqaq_h(findloc(chraq_all,'al',dim=1),ieqaq_h1)
k2al= keqaq_h(findloc(chraq_all,'al',dim=1),ieqaq_h2)
k3al= keqaq_h(findloc(chraq_all,'al',dim=1),ieqaq_h3)
k4al= keqaq_h(findloc(chraq_all,'al',dim=1),ieqaq_h4)
k1fe2 = keqaq_h(findloc(chraq_all,'fe2',dim=1),ieqaq_h1)
k1fe2co3 = keqaq_c(findloc(chraq_all,'fe2',dim=1),ieqaq_co3)
k1fe2hco3  = keqaq_c(findloc(chraq_all,'fe2',dim=1),ieqaq_hco3)
k1fe3= keqaq_h(findloc(chraq_all,'fe3',dim=1),ieqaq_h1)
k2fe3= keqaq_h(findloc(chraq_all,'fe3',dim=1),ieqaq_h2)
k3fe3= keqaq_h(findloc(chraq_all,'fe3',dim=1),ieqaq_h3)
k4fe3= keqaq_h(findloc(chraq_all,'fe3',dim=1),ieqaq_h4)
k1naco3 = keqaq_c(findloc(chraq_all,'na',dim=1),ieqaq_co3)
k1nahco3  = keqaq_c(findloc(chraq_all,'na',dim=1),ieqaq_hco3)

k1so4 = keqaq_h(findloc(chraq_all,'so4',dim=1),ieqaq_h1)
k1naso4 = keqaq_s(findloc(chraq_all,'na',dim=1),ieqaq_so4)
k1kso4 = keqaq_s(findloc(chraq_all,'k',dim=1),ieqaq_so4)
k1caso4 = keqaq_s(findloc(chraq_all,'ca',dim=1),ieqaq_so4)
k1mgso4 = keqaq_s(findloc(chraq_all,'mg',dim=1),ieqaq_so4)
k1fe2so4 = keqaq_s(findloc(chraq_all,'fe2',dim=1),ieqaq_so4)
k1also4 = keqaq_s(findloc(chraq_all,'al',dim=1),ieqaq_so4)
k1fe3so4 = keqaq_s(findloc(chraq_all,'fe3',dim=1),ieqaq_so4)
k1also42 = keqaq_s(findloc(chraq_all,'al',dim=1),ieqaq_so42)
k1fe3so42 = keqaq_s(findloc(chraq_all,'fe3',dim=1),ieqaq_so42)

nax = 0d0
so4x = 0d0
kx = 0d0
if (any(chraq=='na')) then 
    nax = maqx(findloc(chraq,'na',dim=1),:)
elseif (any(chraq_cnst=='na')) then 
    nax = maqc(findloc(chraq_cnst,'na',dim=1),:)
endif 
if (any(chraq=='k')) then 
    kx = maqx(findloc(chraq,'k',dim=1),:)
elseif (any(chraq_cnst=='k')) then 
    kx = maqc(findloc(chraq_cnst,'k',dim=1),:)
endif 
if (any(chraq=='so4')) then 
    so4x = maqx(findloc(chraq,'so4',dim=1),:)
elseif (any(chraq_cnst=='so4')) then 
    so4x = maqc(findloc(chraq_cnst,'so4',dim=1),:)
endif 

! netcat = nax + kx -2d0*so4x
netcat = kx -2d0*so4x

six =0d0
cax =0d0
mgx =0d0
fe2x =0d0
alx =0d0
fe3x =0d0
pco2x =0d0

if (any(chraq=='si')) then 
    six = maqx(findloc(chraq,'si',dim=1),:)
elseif (any(chraq_cnst=='si')) then 
    six = maqc(findloc(chraq_cnst,'si',dim=1),:)
endif 
if (any(chraq=='ca')) then 
    cax = maqx(findloc(chraq,'ca',dim=1),:)
elseif (any(chraq_cnst=='ca')) then 
    cax = maqc(findloc(chraq_cnst,'ca',dim=1),:)
endif 
if (any(chraq=='mg')) then 
    mgx = maqx(findloc(chraq,'mg',dim=1),:)
elseif (any(chraq_cnst=='mg')) then 
    mgx = maqc(findloc(chraq_cnst,'mg',dim=1),:)
endif 
if (any(chraq=='fe2')) then 
    fe2x = maqx(findloc(chraq,'fe2',dim=1),:)
elseif (any(chraq_cnst=='fe2')) then 
    fe2x = maqc(findloc(chraq_cnst,'fe2',dim=1),:)
endif 
if (any(chraq=='al')) then 
    alx = maqx(findloc(chraq,'al',dim=1),:)
elseif (any(chraq_cnst=='al')) then 
    alx = maqc(findloc(chraq_cnst,'al',dim=1),:)
endif 
if (any(chraq=='fe3')) then 
    fe3x = maqx(findloc(chraq,'fe3',dim=1),:)
elseif (any(chraq_cnst=='fe3')) then 
    fe3x = maqc(findloc(chraq_cnst,'fe3',dim=1),:)
endif 
if (any(chrgas=='pco2')) then 
    pco2x = mgasx(findloc(chrgas,'pco2',dim=1),:)
elseif (any(chrgas_cnst=='pco2')) then 
    pco2x = mgasc(findloc(chrgas_cnst,'pco2',dim=1),:)
endif 

if (any(isnan(maqx)) .or. any(isnan(maqc))) then 
    print*,'nan in input aqueosu species'
    stop
endif 

200 continue


call calc_so4( &
    & nz,so4x,nax,kx,mgx,cax,fe2x,alx,fe3x,pco2x,prox &! input 
    & ,nsp_gas_all,nsp_aq_all,chraq_all,chrgas_all,keqgas_h,keqaq_h,keqaq_c,keqaq_s &! input 
    & ,so4f,so4_error &! output
    & )


! print*,'calc_pH'
do while (error > tol)
    f = prox**3d0 + netcat*prox**2d0 - (k1*kco2*pco2x+kw)*prox - 2d0*k2*k1*kco2*pco2x  &
        ! na
        & + nax*prox**2d0/(1d0+k1naco3*k1*k2*kco2*pco2x/prox**2d0+k1nahco3*k1*k2*kco2*pco2x/prox) &
        & -1d0*nax/(1d0+k1naco3*k1*k2*kco2*pco2x/prox**2d0+k1nahco3*k1*k2*kco2*pco2x/prox) &
        &       *k1naco3*k1*k2*kco2*pco2x  &
        ! si 
        ! & - six*prox**2d0/(prox/k1si + 1d0 + k2si/k1si/prox)  &
        ! & - 2d0*six*prox**2d0/(prox**2d0/k2si + prox*k1si/k2si + 1d0) &
        & - six*k1si*prox/(1d0+k1si/prox+k2si/prox**2d0) &
        & - 2d0*six*k2si/(1d0+k1si/prox+k2si/prox**2d0) &
        ! mg
        & + 2d0*mgx*prox**2d0/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox) &
        ! & + mgx*prox**2d0/(prox/(k1mghco3*k1*k2*kco2*pco2x)+k1mg/(k1mghco3*k1*k2*kco2*pco2x)+k1mgco3/k1mghco3/prox+1d0) &
        & + mgx*k1mg*prox/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox) &
        & + mgx*k1mghco3*k1*k2*kco2*pco2x*prox/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox) &
        ! ca
        & + 2d0*cax*prox**2d0/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox) &
        ! & + cax*prox**2d0/(prox/(k1cahco3*k1*k2*kco2*pco2x)+k1ca/(k1cahco3*k1*k2*kco2*pco2x)+k1caco3/k1cahco3/prox+1d0) &
        & + cax*k1ca*prox/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox) &
        & + cax*k1cahco3*k1*k2*kco2*pco2x*prox/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox) &
        ! al
        & + 3d0*alx*prox**2d0/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0) &
        & + 2d0*alx*k1al*prox/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0) &
        & + alx*k2al/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0) &
        & - alx*k4al/prox**2d0/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0) &
        ! fe2
        & + 2d0*fe2x*prox**2d0/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox) &
        ! & + fe2x*prox**2d0/(prox/(k1fe2hco3*k1*k2*kco2*pco2x)+k1fe2/(k1fe2hco3*k1*k2*kco2*pco2x)+k1fe2co3/k1fe2hco3/prox+1d0) &
        & + fe2x*k1fe2*prox/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox) &
        & + fe2x*k1fe2hco3*k1*k2*kco2*pco2x*prox &
        &       /(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox) &
        ! fe3
        & + 3d0*fe3x*prox**2d0/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0) &
        & + 2d0*fe3x*k1fe3*prox/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0) &
        & + fe3x*k2fe3/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0) &
        & - fe3x*k4fe3/prox**2d0/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0) 
    df = 3d0*prox**2d0 + 2d0*netcat*prox - (k1*kco2*pco2x+kw) &
        !
        ! na
        & + nax*prox*2d0/(1d0+k1naco3*k1*k2*kco2*pco2x/prox**2d0+k1nahco3*k1*k2*kco2*pco2x/prox) &
        & + nax*prox**2d0*(-1d0)/(1d0+k1naco3*k1*k2*kco2*pco2x/prox**2d0+k1nahco3*k1*k2*kco2*pco2x/prox)**2d0 &
        &       *(k1naco3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0+k1nahco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0) &
        & -1d0*nax*(-1d0)/(1d0+k1naco3*k1*k2*kco2*pco2x/prox**2d0+k1nahco3*k1*k2*kco2*pco2x/prox)**2d0 &
        &       *k1naco3*k1*k2*kco2*pco2x  &
        &       *(k1naco3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0+k1nahco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0) &
        !
        ! si
        !
        ! & - six*prox*2d0/(prox/k1si + 1d0 + k2si/k1si/prox) &
        ! & - six*prox**2d0*(-1d0)/(prox/k1si + 1d0 + k2si/k1si/prox)**2d0* (1d0/k1si + k2si/k1si*(-1d0)/prox**2d0) &
        ! & - 2d0*six*prox*2d0/(prox**2d0/k2si + prox*k1si/k2si + 1d0) &
        ! & - 2d0*six*prox**2d0*(-1d0)/(prox**2d0/k2si + prox*k1si/k2si + 1d0)**2d0*(prox*2d0/k2si + k1si/k2si) &
        & - six*k1si*1d0/(1d0+k1si/prox+k2si/prox**2d0) &
        & - six*k1si*prox*(-1d0)/(1d0+k1si/prox+k2si/prox**2d0)**2d0* (k1si*(-1d0)/prox**2d0+k2si*(-2d0)/prox**3d0) &
        & - 2d0*six*k2si*(-1d0)/(1d0+k1si/prox+k2si/prox**2d0)**2d0 *(k1si*(-1d0)/prox**2d0+k2si*(-2d0)/prox**3d0) &
        !
        ! mg
        !
        & + 2d0*mgx*prox*2d0/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox) &
        & + 2d0*mgx*prox**2d0*(-1d0) &
        &   /(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox)**2d0 &
        &   *(k1mg*(-1d0)/prox**2d0+k1mgco3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0+k1mghco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0) &
        & + mgx*k1mg*1d0/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox) &
        & + mgx*k1mg*prox*(-1d0)/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox)**2d0 &
        &   *(k1mg*(-1d0)/prox**2d0+k1mgco3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0+k1mghco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0) &
        & + mgx*k1mghco3*k1*k2*kco2*pco2x*1d0/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox) &
        & + mgx*k1mghco3*k1*k2*kco2*pco2x*prox*(-1d0) &
        &   /(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox)**2d0 &
        &   *(k1mg*(-1d0)/prox**2d0+k1mgco3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0+k1mghco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0) &
        ! & + mgx*prox*2d0/(prox/(k1mghco3*k1*k2*kco2*pco2x)+k1mg/(k1mghco3*k1*k2*kco2*pco2x)+k1mgco3/k1mghco3/prox+1d0) &
        ! & + mgx*prox**2d0*(-1d0) &
        ! &   /(prox/(k1mghco3*k1*k2*kco2*pco2x)+k1mg/(k1mghco3*k1*k2*kco2*pco2x)+k1mgco3/k1mghco3/prox+1d0)**2d0 & 
        ! &   *(1d0/(k1mghco3*k1*k2*kco2*pco2x)+k1mgco3/k1mghco3*(-1d0)/prox**2d0)  &
        ! 
        ! ca
        !
        & + 2d0*cax*prox*2d0/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox) &
        & + 2d0*cax*prox**2d0*(-1d0) &
        &   /(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox)**2d0 &
        &   *(k1ca*(-1d0)/prox**2d0+k1caco3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0+k1cahco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0) &
        ! & + cax*prox*2d0/(prox/(k1cahco3*k1*k2*kco2*pco2x)+k1ca/(k1cahco3*k1*k2*kco2*pco2x)+k1caco3/k1cahco3/prox+1d0) &
        ! & + cax*prox**2d0*(-1d0) &
        ! &   /(prox/(k1cahco3*k1*k2*kco2*pco2x)+k1ca/(k1cahco3*k1*k2*kco2*pco2x)+k1caco3/k1cahco3/prox+1d0)**2d0 & 
        ! &   *(1d0/(k1cahco3*k1*k2*kco2*pco2x)+k1caco3/k1cahco3*(-1d0)/prox**2d0)   &
        & + cax*k1ca*1d0/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox) &
        & + cax*k1ca*prox*(-1d0)/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox)**2d0 &
        &   *(k1ca*(-1d0)/prox**2d0+k1caco3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0+k1cahco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0) &
        & + cax*k1cahco3*k1*k2*kco2*pco2x*1d0/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox) &
        & + cax*k1cahco3*k1*k2*kco2*pco2x*prox*(-1d0) &
        &   /(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox)**2d0 &
        &   *(k1ca*(-1d0)/prox**2d0+k1caco3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0+k1cahco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0) &
        !
        ! al
        !
        & + 3d0*alx*prox*2d0/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0) &
        & + 3d0*alx*prox**2d0*(-1d0)/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0)**2d0 &
        &   *(k1al*(-1d0)/prox**2d0+k2al*(-2d0)/prox**3d0+k3al*(-3d0)/prox**4d0+k4al*(-4d0)/prox**5d0) &
        & + 2d0*alx*k1al/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0) &
        & + 2d0*alx*k1al*prox*(-1d0)/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0)**2d0 &
        &   *(k1al*(-1d0)/prox**2d0+k2al*(-2d0)/prox**3d0+k3al*(-3d0)/prox**4d0+k4al*(-4d0)/prox**5d0) &
        & + alx*k2al*(-1d0)/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0)**2d0 &
        &   *(k1al*(-1d0)/prox**2d0+k2al*(-2d0)/prox**3d0+k3al*(-3d0)/prox**4d0+k4al*(-4d0)/prox**5d0) &
        & - alx*k4al*(-2d0)/prox**3d0/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0) &
        & - alx*k4al/prox**2d0*(-1d0)/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0)**2d0 &
        &   *(k1al*(-1d0)/prox**2d0+k2al*(-2d0)/prox**3d0+k3al*(-3d0)/prox**4d0+k4al*(-4d0)/prox**5d0) &
        !
        ! fe2
        ! 
        & + 2d0*fe2x*prox*2d0/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox) &
        & + 2d0*fe2x*prox**2d0*(-1d0) &
        &   /(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox)**2d0 &
        &   *(k1fe2*(-1d0)/prox**2d0+k1fe2co3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0+k1fe2hco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0) &
        ! & + fe2x*prox*2d0/(prox/(k1fe2hco3*k1*k2*kco2*pco2x)+k1fe2/(k1fe2hco3*k1*k2*kco2*pco2x)+k1fe2co3/k1fe2hco3/prox+1d0) &
        ! & + fe2x*prox**2d0*(-1d0) &
        ! &   /(prox/(k1fe2hco3*k1*k2*kco2*pco2x)+k1fe2/(k1fe2hco3*k1*k2*kco2*pco2x)+k1fe2co3/k1fe2hco3/prox+1d0)**2d0 & 
        ! &   *(1d0/(k1fe2hco3*k1*k2*kco2*pco2x)+k1fe2co3/k1fe2hco3*(-1d0)/prox**2d0)  &
        & + fe2x*k1fe2*1d0/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox) &
        & + fe2x*k1fe2*prox*(-1d0)/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox)**2d0 &
        &   *(k1fe2*(-1d0)/prox**2d0+k1fe2co3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0+k1fe2hco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0) &
        & + fe2x*k1fe2hco3*k1*k2*kco2*pco2x*1d0 &
        &       /(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox) &
        & + fe2x*k1fe2hco3*k1*k2*kco2*pco2x*prox*(-1d0) &
        &   /(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox)**2d0 &
        &   *(k1fe2*(-1d0)/prox**2d0+k1fe2co3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0+k1fe2hco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0) &
        !
        ! fe3 
        !
        & + 3d0*fe3x*prox*2d0/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0) &
        & + 3d0*fe3x*prox**2d0*(-1d0)/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0)**2d0 &
        &   *(k1fe3*(-1d0)/prox**2d0+k2fe3*(-2d0)/prox**3d0+k3fe3*(-3d0)/prox**4d0+k4fe3*(-4d0)/prox**5d0) &
        & + 2d0*fe3x*k1fe3/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0) &
        & + 2d0*fe3x*k1fe3*prox*(-1d0)/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0)**2d0 &
        &   *(k1fe3*(-1d0)/prox**2d0+k2fe3*(-2d0)/prox**3d0+k3fe3*(-3d0)/prox**4d0+k4fe3*(-4d0)/prox**5d0) &
        & + fe3x*k2fe3*(-1d0)/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0)**2d0 &
        &   *(k1fe3*(-1d0)/prox**2d0+k2fe3*(-2d0)/prox**3d0+k3fe3*(-3d0)/prox**4d0+k4fe3*(-4d0)/prox**5d0) &
        & - fe3x*k4fe3*(-2d0)/prox**3d0/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0) &
        & - fe3x*k4fe3/prox**2d0*(-1d0)/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0)**2d0 &
        &   *(k1fe3*(-1d0)/prox**2d0+k2fe3*(-2d0)/prox**3d0+k3fe3*(-3d0)/prox**4d0+k4fe3*(-4d0)/prox**5d0)
    df = df*prox
    if (any(isnan(-f/df)) .or. any(isnan(exp(-f/df)))) then 
        print *,any(isnan(-f/df)),any(isnan(exp(-f/df)))
        print *,-f/df
        print *,f
        print *,df
        print *,prox
        print * &
        & ,any(isnan(prox**3d0)), any(isnan(+ netcat*prox**2d0)), any(isnan(- (k1*kco2*pco2x+kw)*prox)) &
        & ,any(isnan( - 2d0*k2*k1*kco2*pco2x )) &
        & ,'si' &
        ! & - six*prox**2d0/(prox/k1si + 1d0 + k2si/k1si/prox)  &
        ! & - 2d0*six*prox**2d0/(prox**2d0/k2si + prox*k1si/k2si + 1d0) &
        & ,any(isnan(- six*k1si*prox/(1d0+k1si/prox+k2si/prox**2d0))) &
        & ,any(isnan(- 2d0*six*k2si/(1d0+k1si/prox+k2si/prox**2d0))) &
        & ,'mg' &
        & ,any(isnan(+ 2d0*mgx*prox**2d0/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox))) &
        ! & + mgx*prox**2d0/(prox/(k1mghco3*k1*k2*kco2*pco2x)+k1mg/(k1mghco3*k1*k2*kco2*pco2x)+k1mgco3/k1mghco3/prox+1d0) &
        & ,any(isnan(+ mgx*k1mg*prox/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox))) &
        & ,any(isnan(+ mgx*k1mghco3*k1*k2*kco2*pco2x*prox &
        &       /(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox))) &
        & ,'ca' &
        & ,any(isnan(+ 2d0*cax*prox**2d0/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox))) &
        ! & + cax*prox**2d0/(prox/(k1cahco3*k1*k2*kco2*pco2x)+k1ca/(k1cahco3*k1*k2*kco2*pco2x)+k1caco3/k1cahco3/prox+1d0) &
        & ,any(isnan(+ cax*k1ca*prox/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox))) &
        & ,any(isnan(+ cax*k1cahco3*k1*k2*kco2*pco2x*prox &
        &       /(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox))) &
        & ,'al' &
        & ,any(isnan(+ 3d0*alx*prox**2d0/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0))) &
        & ,any(isnan(+ 2d0*alx*k1al*prox/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0))) &
        & ,any(isnan(+ alx*k2al/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0))) &
        & ,any(isnan(- alx*k4al/prox**2d0/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0))) &
        & ,'fe2' &
        & ,any(isnan(+ 2d0*fe2x*prox**2d0/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox))) &
        ! & + fe2x*prox**2d0/(prox/(k1fe2hco3*k1*k2*kco2*pco2x)+k1fe2/(k1fe2hco3*k1*k2*kco2*pco2x)+k1fe2co3/k1fe2hco3/prox+1d0) &
        & ,any(isnan(+ fe2x*k1fe2*prox/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox))) &
        & ,any(isnan(+ fe2x*k1fe2hco3*k1*k2*kco2*pco2x*prox &
        &       /(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox))) &
        & ,'fe3'  &
        & ,any(isnan(+ 3d0*fe3x*prox**2d0/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0))) &
        & ,any(isnan(+ 2d0*fe3x*k1fe3*prox/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0))) &
        & ,any(isnan(+ fe3x*k2fe3/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0))) &
        & ,any(isnan(- fe3x*k4fe3/prox**2d0/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0)))  &
        & ,any(isnan(- fe3x*k4fe3/prox**2d0/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0)))  
        ! stop
        ! prox = 10d0
        ! prox = -netcat
        ! goto 200
        ph_error = .true.
        return
    endif 
    prox = prox*exp( -f/df )
    ! do iz = 1, nz
        ! if (-f(iz)/df(iz) > 100d0) then 
            ! prox(iz) = prox(iz)*1.5d0
        ! elseif (-f(iz)/df(iz) > -100d0) then 
            ! prox(iz) = prox(iz)*0.5d0
        ! else 
            ! prox(iz) = prox(iz)*exp( -f(iz)/df(iz) )
        ! endif 
    ! enddo
    error = maxval(abs(exp( -f/df )-1d0))
    if (isnan(error)) error = 1d4
    ! print*, iter,error
    ! print*,  (-log10(prox(iz)),iz=1,nz,nz/5)
    ! print*,  (-log10(f(iz)),iz=1,nz,nz/5)
    ! print*,  (-log10(df(iz)),iz=1,nz,nz/5)
    ! pause
    ! stop
    ! where (prox == 0)
        ! prox = 1d-14
    ! endwhere
    
    iter = iter + 1
enddo 
ph_error = .false.
if (any(isnan(prox))) then     
    print *, (-log10(prox(iz)),iz=1,nz,nz/5)
    print*,'ph is nan'
    ph_error = .true.
    ! stop
endif 

if (print_cb) then 
    open(88,file = trim(adjustl(print_loc)),status='replace')
    write(88,*) ' z ',' h+ ',' oh- ',' na+ ',' naco3- ', ' nahco3 ', ' k+ ',' so42- ', 'hco3- ', ' co32- ' &
        & ,' h4sio4 ',' h3sio4- ',' h2sio42- ' &
        & ,' mg2+ ', ' mg(oh)+ ', ' mgco3 ', 'mghco3+ ', ' ca2+ ', ' ca(oh)+ ', ' caco3 ', ' cahco3+ ' &
        & ,' al3+ ', ' al(oh)2+ ', ' al(oh)2+ ', ' al(oh)3 ', ' al(oh)4- ' &
        & , ' fe22+ ', ' fe2(oh)+ ', ' fe2co3 ', ' fe2hco3+ ' &
        & ,' fe3+ ', ' fe3(oh)2+ ', ' fe3(oh)2+ ', ' fe3(oh)3 ', ' fe3(oh)4- ', ' total_charge ' 
    do iz=1,nz
        write(88,*) z(iz) &
        &, prox(iz) &
        & ,kw/prox(iz) &
        & ,nax(iz)/(1d0+k1naco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0+k1nahco3*k1*k2*kco2*pco2x(iz)/prox(iz)) &
        & ,nax(iz)/(1d0+k1naco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0+k1nahco3*k1*k2*kco2*pco2x(iz)/prox(iz)) &
        &       *k1naco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0 &
        & ,nax(iz)/(1d0+k1naco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0+k1nahco3*k1*k2*kco2*pco2x(iz)/prox(iz)) &
        &       *k1nahco3*k1*k2*kco2*pco2x(iz)/prox(iz)     &
        & ,kx(iz) &
        & ,so4x(iz) &
        & ,k1*kco2*pco2x(iz)/prox(iz) &
        & ,k2*k1*kco2*pco2x(iz)/prox(iz)**2d0 &
        & ,six(iz)/(1d0 + k1si/prox(iz) + k2si/prox(iz)**2d0) &
        & ,six(iz)/(1d0 + k1si/prox(iz) + k2si/prox(iz)**2d0)*k1si/prox(iz) &
        & ,six(iz)/(1d0 + k1si/prox(iz) + k2si/prox(iz)**2d0)*k2si/prox(iz)**2d0 &
        & ,mgx(iz)/(1d0+k1mg/prox(iz)+k1mgco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0+k1mghco3*k1*k2*kco2*pco2x(iz)/prox(iz)) &
        & ,mgx(iz)/(1d0+k1mg/prox(iz)+k1mgco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0+k1mghco3*k1*k2*kco2*pco2x(iz)/prox(iz)) &
        &       *k1mg/prox(iz)  &
        & ,mgx(iz)/(1d0+k1mg/prox(iz)+k1mgco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0+k1mghco3*k1*k2*kco2*pco2x(iz)/prox(iz)) &
        &       *k1mgco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0  &
        & ,mgx(iz)/(1d0+k1mg/prox(iz)+k1mgco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0+k1mghco3*k1*k2*kco2*pco2x(iz)/prox(iz)) &
        &       *k1mghco3*k1*k2*kco2*pco2x(iz)/prox(iz)  &
        & ,cax(iz)/(1d0+k1ca/prox(iz)+k1caco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0+k1cahco3*k1*k2*kco2*pco2x(iz)/prox(iz)) &
        & ,cax(iz)/(1d0+k1ca/prox(iz)+k1caco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0+k1cahco3*k1*k2*kco2*pco2x(iz)/prox(iz)) &
        &       *k1ca/prox(iz) &
        & ,cax(iz)/(1d0+k1ca/prox(iz)+k1caco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0+k1cahco3*k1*k2*kco2*pco2x(iz)/prox(iz)) &
        &       *k1caco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0 &
        & ,cax(iz)/(1d0+k1ca/prox(iz)+k1caco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0+k1cahco3*k1*k2*kco2*pco2x(iz)/prox(iz)) &
        &       *k1cahco3*k1*k2*kco2*pco2x(iz)/prox(iz) &
        & ,alx(iz)/(1d0+k1al/prox(iz)+k2al/prox(iz)**2d0+k3al/prox(iz)**3d0+k4al/prox(iz)**4d0) &
        & ,alx(iz)/(1d0+k1al/prox(iz)+k2al/prox(iz)**2d0+k3al/prox(iz)**3d0+k4al/prox(iz)**4d0)*k1al/prox(iz) &
        & ,alx(iz)/(1d0+k1al/prox(iz)+k2al/prox(iz)**2d0+k3al/prox(iz)**3d0+k4al/prox(iz)**4d0)*k2al/prox(iz)**2d0 &
        & ,alx(iz)/(1d0+k1al/prox(iz)+k2al/prox(iz)**2d0+k3al/prox(iz)**3d0+k4al/prox(iz)**4d0)*k3al/prox(iz)**3d0 &
        & ,alx(iz)/(1d0+k1al/prox(iz)+k2al/prox(iz)**2d0+k3al/prox(iz)**3d0+k4al/prox(iz)**4d0)*k4al/prox(iz)**4d0 &
        & ,fe2x(iz)/(1d0+k1fe2/prox(iz)+k1fe2co3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0+k1fe2hco3*k1*k2*kco2*pco2x(iz)/prox(iz)) &
        & ,fe2x(iz)/(1d0+k1fe2/prox(iz)+k1fe2co3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0+k1fe2hco3*k1*k2*kco2*pco2x(iz)/prox(iz)) &
        &       *k1fe2/prox(iz) &
        & ,fe2x(iz)/(1d0+k1fe2/prox(iz)+k1fe2co3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0+k1fe2hco3*k1*k2*kco2*pco2x(iz)/prox(iz)) &
        &       *k1fe2co3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0 &
        & ,fe2x(iz)/(1d0+k1fe2/prox(iz)+k1fe2co3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0+k1fe2hco3*k1*k2*kco2*pco2x(iz)/prox(iz)) &
        &       *k1fe2hco3*k1*k2*kco2*pco2x(iz)/prox(iz) &
        & ,fe3x(iz)/(1d0+k1fe3/prox(iz)+k2fe3/prox(iz)**2d0+k3fe3/prox(iz)**3d0+k4fe3/prox(iz)**4d0) &
        & ,fe3x(iz)/(1d0+k1fe3/prox(iz)+k2fe3/prox(iz)**2d0+k3fe3/prox(iz)**3d0+k4fe3/prox(iz)**4d0)*k1fe3/prox(iz) &
        & ,fe3x(iz)/(1d0+k1fe3/prox(iz)+k2fe3/prox(iz)**2d0+k3fe3/prox(iz)**3d0+k4fe3/prox(iz)**4d0)*k2fe3/prox(iz)**2d0 &
        & ,fe3x(iz)/(1d0+k1fe3/prox(iz)+k2fe3/prox(iz)**2d0+k3fe3/prox(iz)**3d0+k4fe3/prox(iz)**4d0)*k3fe3/prox(iz)**3d0 &
        & ,fe3x(iz)/(1d0+k1fe3/prox(iz)+k2fe3/prox(iz)**2d0+k3fe3/prox(iz)**3d0+k4fe3/prox(iz)**4d0)*k4fe3/prox(iz)**4d0 &
        ! charge balance 
        & ,1d0*prox(iz) &
        & +(-1d0)*kw/prox(iz) &
        & +(1d0)*nax(iz)/(1d0+k1naco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0+k1nahco3*k1*k2*kco2*pco2x(iz)/prox(iz)) &
        & +(-1d0)*nax(iz)/(1d0+k1naco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0+k1nahco3*k1*k2*kco2*pco2x(iz)/prox(iz)) &
        &       *k1naco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0 &
        & +(0d0)*nax(iz)/(1d0+k1naco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0+k1nahco3*k1*k2*kco2*pco2x(iz)/prox(iz)) &
        &       *k1nahco3*k1*k2*kco2*pco2x(iz)/prox(iz)      &
        & +(1d0)*kx(iz) &
        & +(-2d0)*so4x(iz) &
        & +(-1d0)*k1*kco2*pco2x(iz)/prox(iz) &
        & +(-2d0)*k2*k1*kco2*pco2x(iz)/prox(iz)**2d0 &
        & +(0d0)*six(iz)/(1d0 + k1si/prox(iz) + k2si/prox(iz)**2d0) &
        & +(-1d0)*six(iz)/(1d0 + k1si/prox(iz) + k2si/prox(iz)**2d0)*k1si/prox(iz) &
        & +(-2d0)*six(iz)/(1d0 + k1si/prox(iz) + k2si/prox(iz)**2d0)*k2si/prox(iz)**2d0 &
        & +(2d0)*mgx(iz)/(1d0+k1mg/prox(iz)+k1mgco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0+k1mghco3*k1*k2*kco2*pco2x(iz)/prox(iz)) &
        & +(1d0)*mgx(iz)/(1d0+k1mg/prox(iz)+k1mgco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0+k1mghco3*k1*k2*kco2*pco2x(iz)/prox(iz)) &
        &       *k1mg/prox(iz)  &
        & +(0d0)*mgx(iz)/(1d0+k1mg/prox(iz)+k1mgco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0+k1mghco3*k1*k2*kco2*pco2x(iz)/prox(iz)) &
        &       *k1mgco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0  &
        & +(1d0)*mgx(iz)/(1d0+k1mg/prox(iz)+k1mgco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0+k1mghco3*k1*k2*kco2*pco2x(iz)/prox(iz)) &
        &       *k1mghco3*k1*k2*kco2*pco2x(iz)/prox(iz)  &
        & +(2d0)*cax(iz)/(1d0+k1ca/prox(iz)+k1caco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0+k1cahco3*k1*k2*kco2*pco2x(iz)/prox(iz)) &
        & +(1d0)*cax(iz)/(1d0+k1ca/prox(iz)+k1caco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0+k1cahco3*k1*k2*kco2*pco2x(iz)/prox(iz)) &
        &       *k1ca/prox(iz) &
        & +(0d0)*cax(iz)/(1d0+k1ca/prox(iz)+k1caco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0+k1cahco3*k1*k2*kco2*pco2x(iz)/prox(iz)) &
        &       *k1caco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0 &
        & +(1d0)*cax(iz)/(1d0+k1ca/prox(iz)+k1caco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0+k1cahco3*k1*k2*kco2*pco2x(iz)/prox(iz)) &
        &       *k1cahco3*k1*k2*kco2*pco2x(iz)/prox(iz) &
        & +(3d0)*alx(iz)/(1d0+k1al/prox(iz)+k2al/prox(iz)**2d0+k3al/prox(iz)**3d0+k4al/prox(iz)**4d0) &
        & +(2d0)*alx(iz)/(1d0+k1al/prox(iz)+k2al/prox(iz)**2d0+k3al/prox(iz)**3d0+k4al/prox(iz)**4d0)*k1al/prox(iz) &
        & +(1d0)*alx(iz)/(1d0+k1al/prox(iz)+k2al/prox(iz)**2d0+k3al/prox(iz)**3d0+k4al/prox(iz)**4d0)*k2al/prox(iz)**2d0 &
        & +(0d0)*alx(iz)/(1d0+k1al/prox(iz)+k2al/prox(iz)**2d0+k3al/prox(iz)**3d0+k4al/prox(iz)**4d0)*k3al/prox(iz)**3d0 &
        & +(-1d0)*alx(iz)/(1d0+k1al/prox(iz)+k2al/prox(iz)**2d0+k3al/prox(iz)**3d0+k4al/prox(iz)**4d0)*k4al/prox(iz)**4d0 &
        & +(2d0)*fe2x(iz)/(1d0+k1fe2/prox(iz)+k1fe2co3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0+k1fe2hco3*k1*k2*kco2*pco2x(iz)/prox(iz)) &
        & +(1d0)*fe2x(iz)/(1d0+k1fe2/prox(iz)+k1fe2co3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0+k1fe2hco3*k1*k2*kco2*pco2x(iz)/prox(iz)) &
        &       *k1fe2/prox(iz) &
        & +(0d0)*fe2x(iz)/(1d0+k1fe2/prox(iz)+k1fe2co3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0+k1fe2hco3*k1*k2*kco2*pco2x(iz)/prox(iz)) &
        &       *k1fe2co3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0 &
        & +(1d0)*fe2x(iz)/(1d0+k1fe2/prox(iz)+k1fe2co3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0+k1fe2hco3*k1*k2*kco2*pco2x(iz)/prox(iz)) &
        &       *k1fe2hco3*k1*k2*kco2*pco2x(iz)/prox(iz) &
        & +(3d0)*fe3x(iz)/(1d0+k1fe3/prox(iz)+k2fe3/prox(iz)**2d0+k3fe3/prox(iz)**3d0+k4fe3/prox(iz)**4d0) &
        & +(2d0)*fe3x(iz)/(1d0+k1fe3/prox(iz)+k2fe3/prox(iz)**2d0+k3fe3/prox(iz)**3d0+k4fe3/prox(iz)**4d0)*k1fe3/prox(iz) &
        & +(1d0)*fe3x(iz)/(1d0+k1fe3/prox(iz)+k2fe3/prox(iz)**2d0+k3fe3/prox(iz)**3d0+k4fe3/prox(iz)**4d0)*k2fe3/prox(iz)**2d0 &
        & +(0d0)*fe3x(iz)/(1d0+k1fe3/prox(iz)+k2fe3/prox(iz)**2d0+k3fe3/prox(iz)**3d0+k4fe3/prox(iz)**4d0)*k3fe3/prox(iz)**3d0 &
        & +(-1d0)*fe3x(iz)/(1d0+k1fe3/prox(iz)+k2fe3/prox(iz)**2d0+k3fe3/prox(iz)**3d0+k4fe3/prox(iz)**4d0)*k4fe3/prox(iz)**4d0 
    enddo 
    close(88)
endif 
            

endsubroutine calc_pH_v5

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine calc_pH_v6( &
    & nz,kw,nsp_aq,nsp_gas,nsp_aq_all,nsp_gas_all,nsp_aq_cnst,nsp_gas_cnst &! input 
    & ,chraq,chraq_cnst,chraq_all,chrgas,chrgas_cnst,chrgas_all &!input
    & ,maqx,maqc,mgasx,mgasc,keqgas_h,keqaq_h,keqaq_c,keqaq_s &! input
    & ,print_cb,print_loc,z &! input 
    & ,prox,ph_error &! output
    & ) 
! solving charge balance:
! [H+] + ZX[Xz+] - ZY[YZ-] - [HCO3-] - 2[CO32-] - [OH-] - [H3SiO4-] - 2[H2SiO42-] = 0
! [H+] + ZX[Xz+] - ZY[YZ-] - k1kco2pCO2/[H+] - 2k2k1kco2pCO2/[H+]^2 - kw/[H+] - [Si]/([H+]/k1si + 1 + k2si/k1si/[H+])
!       - 2[Si]/([H+]^2/k2si + [H+]k1si/k2si + 1) = 0
! [H+]^3 + (ZX[Xz+] - ZY[YZ-])[H+]^2 - (k1kco2pCO2+kw)[H+] - 2k2k1kco2pCO2  = 0
! NetCat is defined as (ZX[Xz+] - ZY[YZ-])
! [H+]^3 + NetCat[H+]^2 - (k1kco2pCO2+kw)[H+] - 2k2k1kco2pCO2  = 0
implicit none
integer,intent(in)::nz
real(kind=8),intent(in)::kw
real(kind=8) kco2,k1,k2,k1si,k2si,k1mg,k1mgco3,k1mghco3,k1ca,k1caco3,k1cahco3,k1al,k2al,k3al,k4al &
    & ,k1fe2,k1fe2co3,k1fe2hco3,k1fe3,k2fe3,k3fe3,k4fe3,k1naco3,k1nahco3,k1so4,k1kso4,k1naso4  &
    & ,k1caso4,k1mgso4,k1fe2so4,k1also4,k1also42,k1fe3so4,k1fe3so42
real(kind=8),dimension(nz)::nax,mgx,cax,so4x,pco2x,six,alx,fe2x,fe3x,kx
real(kind=8),dimension(nz)::so4f,naf,kf,mgf,caf,fe2f,fe3f,alf,sif
real(kind=8),dimension(nz)::dso4f_dpro,dnaf_dpro,dkf_dpro,dmgf_dpro,dcaf_dpro,dfe2f_dpro,dfe3f_dpro,dalf_dpro,dsif_dpro
real(kind=8),dimension(nz),intent(in)::z
real(kind=8),dimension(nz),intent(inout)::prox
logical,intent(out)::ph_error

real(kind=8),dimension(nz)::df,f,netcat
real(kind=8) error,tol,dconc
integer iter,iz

integer,intent(in)::nsp_aq,nsp_gas,nsp_aq_all,nsp_gas_all,nsp_aq_cnst,nsp_gas_cnst
character(5),dimension(nsp_aq),intent(in)::chraq
character(5),dimension(nsp_aq_cnst),intent(in)::chraq_cnst
character(5),dimension(nsp_aq_all),intent(in)::chraq_all
character(5),dimension(nsp_gas),intent(in)::chrgas
character(5),dimension(nsp_gas_cnst),intent(in)::chrgas_cnst
character(5),dimension(nsp_gas_all),intent(in)::chrgas_all
real(kind=8),dimension(nsp_aq,nz),intent(in)::maqx
real(kind=8),dimension(nsp_aq_cnst,nz),intent(in)::maqc
real(kind=8),dimension(nsp_gas,nz),intent(in)::mgasx
real(kind=8),dimension(nsp_gas_cnst,nz),intent(in)::mgasc
real(kind=8),dimension(nsp_gas_all,3),intent(in)::keqgas_h
real(kind=8),dimension(nsp_aq_all,4),intent(in)::keqaq_h
real(kind=8),dimension(nsp_aq_all,2),intent(in)::keqaq_c
real(kind=8),dimension(nsp_aq_all,2),intent(in)::keqaq_s

integer ieqgas_h0,ieqgas_h1,ieqgas_h2
data ieqgas_h0,ieqgas_h1,ieqgas_h2/1,2,3/

integer ieqaq_h1,ieqaq_h2,ieqaq_h3,ieqaq_h4
data ieqaq_h1,ieqaq_h2,ieqaq_h3,ieqaq_h4/1,2,3,4/

integer ieqaq_co3,ieqaq_hco3
data ieqaq_co3,ieqaq_hco3/1,2/

integer ieqaq_so4,ieqaq_so42
data ieqaq_so4,ieqaq_so42/1,2/

logical,intent(in)::print_cb
character(500),intent(in)::print_loc
logical so4_error

error = 1d4
tol = 1d-6
dconc = 1d-14

prox = 1d0 
iter = 0


kco2 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h0)
k1 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h1)
k2 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h2)
k1si = keqaq_h(findloc(chraq_all,'si',dim=1),ieqaq_h1)
k2si = keqaq_h(findloc(chraq_all,'si',dim=1),ieqaq_h2)
k1mg = keqaq_h(findloc(chraq_all,'mg',dim=1),ieqaq_h1)
k1mgco3 = keqaq_c(findloc(chraq_all,'mg',dim=1),ieqaq_co3)
k1mghco3  = keqaq_c(findloc(chraq_all,'mg',dim=1),ieqaq_hco3)
k1ca = keqaq_h(findloc(chraq_all,'ca',dim=1),ieqaq_h1)
k1caco3 = keqaq_c(findloc(chraq_all,'ca',dim=1),ieqaq_co3)
k1cahco3 = keqaq_c(findloc(chraq_all,'ca',dim=1),ieqaq_hco3)
k1al= keqaq_h(findloc(chraq_all,'al',dim=1),ieqaq_h1)
k2al= keqaq_h(findloc(chraq_all,'al',dim=1),ieqaq_h2)
k3al= keqaq_h(findloc(chraq_all,'al',dim=1),ieqaq_h3)
k4al= keqaq_h(findloc(chraq_all,'al',dim=1),ieqaq_h4)
k1fe2 = keqaq_h(findloc(chraq_all,'fe2',dim=1),ieqaq_h1)
k1fe2co3 = keqaq_c(findloc(chraq_all,'fe2',dim=1),ieqaq_co3)
k1fe2hco3  = keqaq_c(findloc(chraq_all,'fe2',dim=1),ieqaq_hco3)
k1fe3= keqaq_h(findloc(chraq_all,'fe3',dim=1),ieqaq_h1)
k2fe3= keqaq_h(findloc(chraq_all,'fe3',dim=1),ieqaq_h2)
k3fe3= keqaq_h(findloc(chraq_all,'fe3',dim=1),ieqaq_h3)
k4fe3= keqaq_h(findloc(chraq_all,'fe3',dim=1),ieqaq_h4)
k1naco3 = keqaq_c(findloc(chraq_all,'na',dim=1),ieqaq_co3)
k1nahco3  = keqaq_c(findloc(chraq_all,'na',dim=1),ieqaq_hco3)

k1so4 = keqaq_h(findloc(chraq_all,'so4',dim=1),ieqaq_h1)
k1naso4 = keqaq_s(findloc(chraq_all,'na',dim=1),ieqaq_so4)
k1kso4 = keqaq_s(findloc(chraq_all,'k',dim=1),ieqaq_so4)
k1caso4 = keqaq_s(findloc(chraq_all,'ca',dim=1),ieqaq_so4)
k1mgso4 = keqaq_s(findloc(chraq_all,'mg',dim=1),ieqaq_so4)
k1fe2so4 = keqaq_s(findloc(chraq_all,'fe2',dim=1),ieqaq_so4)
k1also4 = keqaq_s(findloc(chraq_all,'al',dim=1),ieqaq_so4)
k1fe3so4 = keqaq_s(findloc(chraq_all,'fe3',dim=1),ieqaq_so4)
k1also42 = keqaq_s(findloc(chraq_all,'al',dim=1),ieqaq_so42)
k1fe3so42 = keqaq_s(findloc(chraq_all,'fe3',dim=1),ieqaq_so42)

nax = 0d0
so4x = 0d0
kx = 0d0
if (any(chraq=='na')) then 
    nax = maqx(findloc(chraq,'na',dim=1),:)
elseif (any(chraq_cnst=='na')) then 
    nax = maqc(findloc(chraq_cnst,'na',dim=1),:)
endif 
if (any(chraq=='k')) then 
    kx = maqx(findloc(chraq,'k',dim=1),:)
elseif (any(chraq_cnst=='k')) then 
    kx = maqc(findloc(chraq_cnst,'k',dim=1),:)
endif 
if (any(chraq=='so4')) then 
    so4x = maqx(findloc(chraq,'so4',dim=1),:)
elseif (any(chraq_cnst=='so4')) then 
    so4x = maqc(findloc(chraq_cnst,'so4',dim=1),:)
endif 

! netcat = nax + kx -2d0*so4x
! netcat = kx -2d0*so4x
netcat = 0d0

six =0d0
cax =0d0
mgx =0d0
fe2x =0d0
alx =0d0
fe3x =0d0
pco2x =0d0

if (any(chraq=='si')) then 
    six = maqx(findloc(chraq,'si',dim=1),:)
elseif (any(chraq_cnst=='si')) then 
    six = maqc(findloc(chraq_cnst,'si',dim=1),:)
endif 
if (any(chraq=='ca')) then 
    cax = maqx(findloc(chraq,'ca',dim=1),:)
elseif (any(chraq_cnst=='ca')) then 
    cax = maqc(findloc(chraq_cnst,'ca',dim=1),:)
endif 
if (any(chraq=='mg')) then 
    mgx = maqx(findloc(chraq,'mg',dim=1),:)
elseif (any(chraq_cnst=='mg')) then 
    mgx = maqc(findloc(chraq_cnst,'mg',dim=1),:)
endif 
if (any(chraq=='fe2')) then 
    fe2x = maqx(findloc(chraq,'fe2',dim=1),:)
elseif (any(chraq_cnst=='fe2')) then 
    fe2x = maqc(findloc(chraq_cnst,'fe2',dim=1),:)
endif 
if (any(chraq=='al')) then 
    alx = maqx(findloc(chraq,'al',dim=1),:)
elseif (any(chraq_cnst=='al')) then 
    alx = maqc(findloc(chraq_cnst,'al',dim=1),:)
endif 
if (any(chraq=='fe3')) then 
    fe3x = maqx(findloc(chraq,'fe3',dim=1),:)
elseif (any(chraq_cnst=='fe3')) then 
    fe3x = maqc(findloc(chraq_cnst,'fe3',dim=1),:)
endif 
if (any(chrgas=='pco2')) then 
    pco2x = mgasx(findloc(chrgas,'pco2',dim=1),:)
elseif (any(chrgas_cnst=='pco2')) then 
    pco2x = mgasc(findloc(chrgas_cnst,'pco2',dim=1),:)
endif 

if (any(isnan(maqx)) .or. any(isnan(maqc))) then 
    print*,'nan in input aqueosu species'
    stop
endif 

200 continue


! print*,'calc_pH'
do while (error > tol)
    ! free SO42- (for simplicity only consider XSO4 complex where X is a cation)
    
    if (any(so4x==0d0)) then 
        so4f = so4x
        dso4f_dpro = 0d0
    else 
        ! print*,'so4x'
        ! print*,so4x
        call calc_so4( &
            & nz,so4x,nax,kx,mgx,cax,fe2x,alx,fe3x,pco2x,prox &! input 
            & ,nsp_gas_all,nsp_aq_all,chraq_all,chrgas_all,keqgas_h,keqaq_h,keqaq_c,keqaq_s &! input 
            & ,so4f,so4_error &! output
            & )
        call calc_so4( &
            & nz,so4x,nax,kx,mgx,cax,fe2x,alx,fe3x,pco2x,prox+dconc &! input 
            & ,nsp_gas_all,nsp_aq_all,chraq_all,chrgas_all,keqgas_h,keqaq_h,keqaq_c,keqaq_s &! input 
            & ,dso4f_dpro,so4_error &! output
            & )
        dso4f_dpro = (dso4f_dpro - so4f)/dconc 
    endif 
    
    kf = kx/(1d0+k1kso4*so4f)
    dkf_dpro = kx*(-1d0)/(1d0+k1kso4*so4f)**2d0*(k1kso4*dso4f_dpro)
    
    naf = nax/(1d0+k1naco3*k1*k2*kco2*pco2x/prox**2d0+k1nahco3*k1*k2*kco2*pco2x/prox+k1naso4*so4f)
    dnaf_dpro = nax*(-1d0)/(1d0+k1naco3*k1*k2*kco2*pco2x/prox**2d0+k1nahco3*k1*k2*kco2*pco2x/prox+k1naso4*so4f)**2d0 &
        & *(k1naco3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0+k1nahco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0+k1naso4*dso4f_dpro)
        
    caf = cax/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox+k1caso4*so4f)
    dcaf_dpro = cax*(-1d0)/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox+k1caso4*so4f)**2d0 &
        & *(k1ca*(-1d0)/prox**2d0+k1caco3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0+k1cahco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0 &
        &   +k1caso4*dso4f_dpro)
        
    mgf = mgx/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox+k1mgso4*so4f)
    dmgf_dpro = mgx*(-1d0)/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox+k1mgso4*so4f)**2d0 &
        & *(k1mg*(-1d0)/prox**2d0+k1mgco3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0+k1mghco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0 &
        &   +k1mgso4*dso4f_dpro)
        
    fe2f = fe2x/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox+k1fe2so4*so4f)
    dfe2f_dpro = fe2x*(-1d0) &
        & /(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox+k1fe2so4*so4f)**2d0 &
        & *(k1fe2*(-1d0)/prox**2d0+k1fe2co3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0+k1fe2hco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0 &
        &   +k1fe2so4*dso4f_dpro)
        
    sif = six/(1d0+k1si/prox+k2si/prox**2d0)
    dsif_dpro = six*(-1d0)/(k1si*(-1d0)/prox**2d0+k2si*(-2d0)/prox**3d0)
    
    alf = alx/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0+k1also4*so4f)
    dalf_dpro = alx*(-1d0)/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0+k1also4*so4f)**2d0 &
        & *(k1al*(-1d0)/prox**2d0+k2al*(-2d0)/prox**3d0+k3al*(-3d0)/prox**4d0+k4al*(-4d0)/prox**5d0+k1also4*dso4f_dpro)
    
    fe3f = fe3x/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0+k1fe3so4*so4f)
    dfe3f_dpro = fe3x*(-1d0)/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0+k1fe3so4*so4f)**2d0 &
        & *(k1fe3*(-1d0)/prox**2d0+k2fe3*(-2d0)/prox**3d0+k3fe3*(-3d0)/prox**4d0+k4fe3*(-4d0)/prox**5d0+k1fe3so4*dso4f_dpro)
    
    f = prox**3d0 + netcat*prox**2d0 - (k1*kco2*pco2x+kw)*prox - 2d0*k2*k1*kco2*pco2x  &
        ! so4
        & -2d0*so4f*prox**2d0 &
        & -1d0*so4f*prox*k1so4 &
        ! k
        & + kf*prox**2d0 &
        & - kf*prox**2d0*k1kso4*so4f &
        ! na
        & + naf*prox**2d0 &
        & -1d0*naf*k1naco3*k1*k2*kco2*pco2x  &
        & -1d0*naf*prox**2d0*k1naso4*so4f  &
        ! si 
        & - sif*k1si*prox &
        & - 2d0*sif*k2si &
        ! mg
        & + 2d0*mgf*prox**2d0 &
        & + mgf*k1mg*prox &
        & + mgf*k1mghco3*k1*k2*kco2*pco2x*prox  &
        ! ca
        & + 2d0*caf*prox**2d0 &
        & + caf*k1ca*prox &
        & + caf*k1cahco3*k1*k2*kco2*pco2x*prox &
        ! al
        & + 3d0*alf*prox**2d0 &
        & + 2d0*alf*k1al*prox &
        & + alf*k2al &
        & - alf*k4al/prox**2d0 &
        & + alf*k1also4*so4f*prox**2d0 &
        ! fe2
        & + 2d0*fe2f*prox**2d0 &
        & + fe2f*k1fe2*prox &
        & + fe2f*k1fe2hco3*k1*k2*kco2*pco2x*prox &
        ! fe3
        & + 3d0*fe3f*prox**2d0 &
        & + 2d0*fe3f*k1fe3*prox &
        & + fe3f*k2fe3 &
        & - fe3f*k4fe3/prox**2d0 &
        & + fe3f*k1fe3so4*so4f*prox**2d0 
    df = 3d0*prox**2d0 + 2d0*netcat*prox - (k1*kco2*pco2x+kw) &
        !
        ! so4
        & -2d0*dso4f_dpro*prox**2d0 &
        & -2d0*so4f*prox*2d0 &
        & -1d0*dso4f_dpro*prox*k1so4 &
        & -1d0*so4f*k1so4 &
        !
        ! k
        & + dkf_dpro*prox**2d0 &
        & + kf*prox*2d0 &
        & - dkf_dpro*prox**2d0*k1kso4*so4f &
        & - kf*prox*2d0*k1kso4*so4f &
        & - kf*prox**2d0*k1kso4*dso4f_dpro &
        !
        ! na
        & + dnaf_dpro*prox**2d0 &
        & + naf*prox*2d0 &
        & -1d0*dnaf_dpro*k1naco3*k1*k2*kco2*pco2x  &
        & -1d0*dnaf_dpro*prox**2d0*k1naso4*so4f  &
        & -1d0*naf*prox*2d0*k1naso4*so4f  &
        & -1d0*naf*prox**2d0*k1naso4*dso4f_dpro  &
        !
        ! si
        !
        & - dsif_dpro*k1si*prox &
        & - sif*k1si*1d0 &
        & - 2d0*dsif_dpro*k2si &
        !
        ! mg
        !
        & + 2d0*dmgf_dpro*prox**2d0 &
        & + 2d0*mgf*prox*2d0 &
        & + dmgf_dpro*k1mg*prox &
        & + mgf*k1mg*1d0 &
        & + dmgf_dpro*k1mghco3*k1*k2*kco2*pco2x*prox  &
        & + mgf*k1mghco3*k1*k2*kco2*pco2x*1d0  &
        ! 
        ! ca
        !
        & + 2d0*dcaf_dpro*prox**2d0 &
        & + 2d0*caf*prox*2d0 &
        & + dcaf_dpro*k1ca*prox &
        & + caf*k1ca*1d0 &
        & + dcaf_dpro*k1cahco3*k1*k2*kco2*pco2x*prox  &
        & + caf*k1cahco3*k1*k2*kco2*pco2x*1d0  &
        !
        ! al
        !
        & + 3d0*dalf_dpro*prox**2d0 &
        & + 3d0*alf*prox*2d0 &
        & + 2d0*dalf_dpro*k1al*prox &
        & + 2d0*alf*k1al*1d0 &
        & + dalf_dpro*k2al &
        & - dalf_dpro*k4al/prox**2d0 &
        & - alf*k4al*(-2d0)/prox**3d0 &
        & + dalf_dpro*k1also4*so4f*prox**2d0 &
        & + alf*k1also4*dso4f_dpro*prox**2d0 &
        & + alf*k1also4*so4f*prox*2d0 &
        !
        ! fe2
        ! 
        & + 2d0*dfe2f_dpro*prox**2d0 &
        & + 2d0*fe2f*prox*2d0 &
        & + dfe2f_dpro*k1fe2*prox &
        & + fe2f*k1fe2*1d0 &
        & + dfe2f_dpro*k1fe2hco3*k1*k2*kco2*pco2x*prox  &
        & + fe2f*k1fe2hco3*k1*k2*kco2*pco2x*1d0  &
        !
        ! fe3 
        !
        & + 3d0*dfe3f_dpro*prox**2d0 &
        & + 3d0*fe3f*prox*2d0 &
        & + 2d0*dfe3f_dpro*k1fe3*prox &
        & + 2d0*fe3f*k1fe3*1d0 &
        & + dfe3f_dpro*k2fe3 &
        & - dfe3f_dpro*k4fe3/prox**2d0 &
        & - fe3f*k4fe3*(-2d0)/prox**3d0 &
        & + dfe3f_dpro*k1fe3so4*so4f*prox**2d0 &
        & + fe3f*k1fe3so4*dso4f_dpro*prox**2d0 &
        & + fe3f*k1fe3so4*so4f*prox*2d0 
        
    df = df*prox
    if (any(isnan(-f/df)) .or. any(isnan(exp(-f/df)))) then 
        print *,any(isnan(-f/df)),any(isnan(exp(-f/df)))
        print *,-f/df
        print *,f
        print *,df
        print *,prox
        print * &
        & ,any(isnan(prox**3d0)), any(isnan(+ netcat*prox**2d0)), any(isnan(- (k1*kco2*pco2x+kw)*prox)) &
        & ,any(isnan( - 2d0*k2*k1*kco2*pco2x )) &
        & ,'si' &
        ! & - six*prox**2d0/(prox/k1si + 1d0 + k2si/k1si/prox)  &
        ! & - 2d0*six*prox**2d0/(prox**2d0/k2si + prox*k1si/k2si + 1d0) &
        & ,any(isnan(- six*k1si*prox/(1d0+k1si/prox+k2si/prox**2d0))) &
        & ,any(isnan(- 2d0*six*k2si/(1d0+k1si/prox+k2si/prox**2d0))) &
        & ,'mg' &
        & ,any(isnan(+ 2d0*mgx*prox**2d0/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox))) &
        ! & + mgx*prox**2d0/(prox/(k1mghco3*k1*k2*kco2*pco2x)+k1mg/(k1mghco3*k1*k2*kco2*pco2x)+k1mgco3/k1mghco3/prox+1d0) &
        & ,any(isnan(+ mgx*k1mg*prox/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox))) &
        & ,any(isnan(+ mgx*k1mghco3*k1*k2*kco2*pco2x*prox &
        &       /(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox))) &
        & ,'ca' &
        & ,any(isnan(+ 2d0*cax*prox**2d0/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox))) &
        ! & + cax*prox**2d0/(prox/(k1cahco3*k1*k2*kco2*pco2x)+k1ca/(k1cahco3*k1*k2*kco2*pco2x)+k1caco3/k1cahco3/prox+1d0) &
        & ,any(isnan(+ cax*k1ca*prox/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox))) &
        & ,any(isnan(+ cax*k1cahco3*k1*k2*kco2*pco2x*prox &
        &       /(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox))) &
        & ,'al' &
        & ,any(isnan(+ 3d0*alx*prox**2d0/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0))) &
        & ,any(isnan(+ 2d0*alx*k1al*prox/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0))) &
        & ,any(isnan(+ alx*k2al/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0))) &
        & ,any(isnan(- alx*k4al/prox**2d0/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0))) &
        & ,'fe2' &
        & ,any(isnan(+ 2d0*fe2x*prox**2d0/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox))) &
        ! & + fe2x*prox**2d0/(prox/(k1fe2hco3*k1*k2*kco2*pco2x)+k1fe2/(k1fe2hco3*k1*k2*kco2*pco2x)+k1fe2co3/k1fe2hco3/prox+1d0) &
        & ,any(isnan(+ fe2x*k1fe2*prox/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox))) &
        & ,any(isnan(+ fe2x*k1fe2hco3*k1*k2*kco2*pco2x*prox &
        &       /(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox))) &
        & ,'fe3'  &
        & ,any(isnan(+ 3d0*fe3x*prox**2d0/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0))) &
        & ,any(isnan(+ 2d0*fe3x*k1fe3*prox/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0))) &
        & ,any(isnan(+ fe3x*k2fe3/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0))) &
        & ,any(isnan(- fe3x*k4fe3/prox**2d0/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0)))  &
        & ,any(isnan(- fe3x*k4fe3/prox**2d0/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0)))  
        ! stop
        ! prox = 10d0
        ! prox = -netcat
        ! goto 200
        ph_error = .true.
        return
    endif 
    prox = prox*exp( -f/df )
    ! do iz = 1, nz
        ! if (-f(iz)/df(iz) > 100d0) then 
            ! prox(iz) = prox(iz)*1.5d0
        ! elseif (-f(iz)/df(iz) > -100d0) then 
            ! prox(iz) = prox(iz)*0.5d0
        ! else 
            ! prox(iz) = prox(iz)*exp( -f(iz)/df(iz) )
        ! endif 
    ! enddo
    error = maxval(abs(exp( -f/df )-1d0))
    if (isnan(error)) error = 1d4
    ! print*, iter,error
    ! print*,  (-log10(prox(iz)),iz=1,nz,nz/5)
    ! print*,  (-log10(f(iz)),iz=1,nz,nz/5)
    ! print*,  (-log10(df(iz)),iz=1,nz,nz/5)
    ! pause
    ! stop
    ! where (prox == 0)
        ! prox = 1d-14
    ! endwhere
    
    iter = iter + 1
enddo 
ph_error = .false.
if (any(isnan(prox))) then     
    print *, (-log10(prox(iz)),iz=1,nz,nz/5)
    print*,'ph is nan'
    ph_error = .true.
    ! stop
endif 

if (any(so4x==0d0)) then 
    so4f = so4x
else 
    call calc_so4( &
        & nz,so4x,nax,kx,mgx,cax,fe2x,alx,fe3x,pco2x,prox &! input 
        & ,nsp_gas_all,nsp_aq_all,chraq_all,chrgas_all,keqgas_h,keqaq_h,keqaq_c,keqaq_s &! input 
        & ,so4f,so4_error &! output
        & )
endif 
    
kf = kx/(1d0+k1kso4*so4f)

naf = nax/(1d0+k1naco3*k1*k2*kco2*pco2x/prox**2d0+k1nahco3*k1*k2*kco2*pco2x/prox+k1naso4*so4f)
    
caf = cax/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox+k1caso4*so4f)
    
mgf = mgx/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox+k1mgso4*so4f)
    
fe2f = fe2x/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox+k1fe2so4*so4f)
    
sif = six/(1d0+k1si/prox+k2si/prox**2d0)

alf = alx/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0+k1also4*so4f)

fe3f = fe3x/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0+k1fe3so4*so4f)

if (print_cb) then 
    open(88,file = trim(adjustl(print_loc)),status='replace')
    write(88,*) ' z ',' h+ ',' oh- ',' na+ ',' naco3- ', ' nahco3 ', ' naso4- ', ' k+ ',' kso4- ' &
        & ,' so42- ', ' hso4- ', 'hco3- ', ' co32- ' &
        & ,' h4sio4 ',' h3sio4- ',' h2sio42- ' &
        & ,' mg2+ ', ' mg(oh)+ ', ' mgco3 ', 'mghco3+ ', 'mgso4 ' &
        & , ' ca2+ ', ' ca(oh)+ ', ' caco3 ', ' cahco3+ ', ' caso4 ' &
        & ,' al3+ ', ' al(oh)2+ ', ' al(oh)2+ ', ' al(oh)3 ', ' al(oh)4- ' , ' also4+ ' &
        & , ' fe22+ ', ' fe2(oh)+ ', ' fe2co3 ', ' fe2hco3+ ', ' fe2so4 ' &
        & ,' fe3+ ', ' fe3(oh)2+ ', ' fe3(oh)2+ ', ' fe3(oh)3 ', ' fe3(oh)4- ', ' fe3so4+ ' &
        & , ' total_charge ' 
    do iz=1,nz
        write(88,*) z(iz) &
        &, prox(iz) &
        & ,kw/prox(iz) &
        & ,naf(iz) &
        & ,naf(iz)*k1naco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0 &
        & ,naf(iz)*k1nahco3*k1*k2*kco2*pco2x(iz)/prox(iz)     &
        & ,naf(iz)*k1naso4*so4f(iz)     &
        & ,kf(iz) &
        & ,kf(iz)*k1kso4*so4f(iz) &
        & ,so4f(iz) &
        & ,so4f(iz)*k1so4/prox &
        & ,k1*kco2*pco2x(iz)/prox(iz) &
        & ,k2*k1*kco2*pco2x(iz)/prox(iz)**2d0 &
        & ,sif(iz) &
        & ,sif(iz)*k1si/prox(iz) &
        & ,sif(iz)*k2si/prox(iz)**2d0 &
        & ,mgf(iz) &
        & ,mgf(iz)*k1mg/prox(iz)  &
        & ,mgf(iz)*k1mgco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0  &
        & ,mgf(iz)*k1mghco3*k1*k2*kco2*pco2x(iz)/prox(iz)  &
        & ,mgf(iz)*k1mgso4*so4f(iz)  &
        & ,caf(iz) &
        & ,caf(iz)*k1ca/prox(iz) &
        & ,caf(iz)*k1caco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0 &
        & ,caf(iz)*k1cahco3*k1*k2*kco2*pco2x(iz)/prox(iz) &
        & ,caf(iz)*k1caso4*so4f(iz) &
        & ,alf(iz) &
        & ,alf(iz)*k1al/prox(iz) &
        & ,alf(iz)*k2al/prox(iz)**2d0 &
        & ,alf(iz)*k3al/prox(iz)**3d0 &
        & ,alf(iz)*k4al/prox(iz)**4d0 &
        & ,alf(iz)*k1also4*so4f(iz) &
        & ,fe2f(iz) &
        & ,fe2f(iz)*k1fe2/prox(iz) &
        & ,fe2f(iz)*k1fe2co3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0 &
        & ,fe2f(iz)*k1fe2hco3*k1*k2*kco2*pco2x(iz)/prox(iz) &
        & ,fe2f(iz)*k1fe2so4*so4f(iz) &
        & ,fe3f(iz) &
        & ,fe3f(iz)*k1fe3/prox(iz) &
        & ,fe3f(iz)*k2fe3/prox(iz)**2d0 &
        & ,fe3f(iz)*k3fe3/prox(iz)**3d0 &
        & ,fe3f(iz)*k4fe3/prox(iz)**4d0 &
        & ,fe3f(iz)*k1fe3so4*so4f(iz) &
        ! charge balance 
        & ,1d0*prox(iz) &
        & +(-1d0)*kw/prox(iz) &
        & +(1d0)*naf(iz) &
        & +(-1d0)*naf(iz)*k1naco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0 &
        & +(0d0)*naf(iz)*k1nahco3*k1*k2*kco2*pco2x(iz)/prox(iz)      &
        & +(-1d0)*naf(iz)*k1naso4*so4f(iz)     &
        & +(1d0)*kf(iz) &
        & +(-1d0)*kf(iz)*k1kso4*so4f(iz) &
        & +(-2d0)*so4f(iz) &
        & +(-1d0)*so4f(iz)*k1so4/prox &
        & +(-1d0)*k1*kco2*pco2x(iz)/prox(iz) &
        & +(-2d0)*k2*k1*kco2*pco2x(iz)/prox(iz)**2d0 &
        & +(0d0)*sif(iz) &
        & +(-1d0)*sif(iz)*k1si/prox(iz) &
        & +(-2d0)*sif(iz)*k2si/prox(iz)**2d0 &
        & +(2d0)*mgf(iz) &
        & +(1d0)*mgf(iz)*k1mg/prox(iz)  &
        & +(0d0)*mgf(iz)*k1mgco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0  &
        & +(1d0)*mgf(iz)*k1mghco3*k1*k2*kco2*pco2x(iz)/prox(iz)  &
        & +(0d0)*mgf(iz)*k1mgso4*so4f(iz)  &
        & +(2d0)*caf(iz) &
        & +(1d0)*caf(iz)*k1ca/prox(iz) &
        & +(0d0)*caf(iz)*k1caco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0 &
        & +(1d0)*caf(iz)*k1cahco3*k1*k2*kco2*pco2x(iz)/prox(iz) &
        & +(0d0)*caf(iz)*k1caso4*so4f(iz) &
        & +(3d0)*alx(iz) &
        & +(2d0)*alx(iz)*k1al/prox(iz) &
        & +(1d0)*alx(iz)*k2al/prox(iz)**2d0 &
        & +(0d0)*alx(iz)*k3al/prox(iz)**3d0 &
        & +(-1d0)*alx(iz)*k4al/prox(iz)**4d0 &
        & +(1d0)*alx(iz)*k1also4*so4f(iz) &
        & +(2d0)*fe2x(iz) &
        & +(1d0)*fe2x(iz)*k1fe2/prox(iz) &
        & +(0d0)*fe2x(iz)*k1fe2co3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0 &
        & +(1d0)*fe2x(iz)*k1fe2hco3*k1*k2*kco2*pco2x(iz)/prox(iz) &
        & +(0d0)*fe2x(iz)*k1fe2so4*so4f(iz) &
        & +(3d0)*fe3x(iz) &
        & +(2d0)*fe3x(iz)*k1fe3/prox(iz) &
        & +(1d0)*fe3x(iz)*k2fe3/prox(iz)**2d0 &
        & +(0d0)*fe3x(iz)*k3fe3/prox(iz)**3d0 &
        & +(-1d0)*fe3x(iz)*k4fe3/prox(iz)**4d0 &
        & +(-1d0)*fe3x(iz)*k1fe3so4*so4f(iz) 
    enddo 
    close(88)
endif 
            

endsubroutine calc_pH_v6

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine calc_pH_v7( &
    & nz,kw,nsp_aq,nsp_gas,nsp_aq_all,nsp_gas_all,nsp_aq_cnst,nsp_gas_cnst &! input 
    & ,chraq,chraq_cnst,chraq_all,chrgas,chrgas_cnst,chrgas_all &!input
    & ,maqx,maqc,mgasx,mgasc,keqgas_h,keqaq_h,keqaq_c,keqaq_s,maqth_all &! input
    & ,print_cb,print_loc,z &! input 
    & ,prox,ph_error,so4f &! output
    & ) 
! solving charge balance:
! [H+] + ZX[Xz+] - ZY[YZ-] - [HCO3-] - 2[CO32-] - [OH-] - [H3SiO4-] - 2[H2SiO42-] = 0
! [H+] + ZX[Xz+] - ZY[YZ-] - k1kco2pCO2/[H+] - 2k2k1kco2pCO2/[H+]^2 - kw/[H+] - [Si]/([H+]/k1si + 1 + k2si/k1si/[H+])
!       - 2[Si]/([H+]^2/k2si + [H+]k1si/k2si + 1) = 0
! [H+]^3 + (ZX[Xz+] - ZY[YZ-])[H+]^2 - (k1kco2pCO2+kw)[H+] - 2k2k1kco2pCO2  = 0
! NetCat is defined as (ZX[Xz+] - ZY[YZ-])
! [H+]^3 + NetCat[H+]^2 - (k1kco2pCO2+kw)[H+] - 2k2k1kco2pCO2  = 0
implicit none
integer,intent(in)::nz
real(kind=8),intent(in)::kw
real(kind=8) kco2,k1,k2,k1si,k2si,k1mg,k1mgco3,k1mghco3,k1ca,k1caco3,k1cahco3,k1al,k2al,k3al,k4al &
    & ,k1fe2,k1fe2co3,k1fe2hco3,k1fe3,k2fe3,k3fe3,k4fe3,k1naco3,k1nahco3,k1so4,k1kso4,k1naso4  &
    & ,k1caso4,k1mgso4,k1fe2so4,k1also4,k1also42,k1fe3so4,k1fe3so42,so4th
real(kind=8),dimension(nz)::nax,mgx,cax,so4x,pco2x,six,alx,fe2x,fe3x,kx
real(kind=8),dimension(nz)::naf,kf,mgf,caf,fe2f,fe3f,alf,sif
real(kind=8),dimension(nz)::dnaf_dpro,dkf_dpro,dmgf_dpro,dcaf_dpro,dfe2f_dpro,dfe3f_dpro,dalf_dpro,dsif_dpro
real(kind=8),dimension(nz)::dnaf_dso4f,dkf_dso4f,dmgf_dso4f,dcaf_dso4f,dfe2f_dso4f,dfe3f_dso4f,dalf_dso4f,dsif_dso4f
real(kind=8),dimension(nz),intent(in)::z
real(kind=8),dimension(nz),intent(inout)::prox,so4f
logical,intent(out)::ph_error

real(kind=8),dimension(nz)::df1,f1,netcat,f2,df2,df21,df12
real(kind=8) error,tol,dconc
integer iter,iz

integer,intent(in)::nsp_aq,nsp_gas,nsp_aq_all,nsp_gas_all,nsp_aq_cnst,nsp_gas_cnst
character(5),dimension(nsp_aq),intent(in)::chraq
character(5),dimension(nsp_aq_cnst),intent(in)::chraq_cnst
character(5),dimension(nsp_aq_all),intent(in)::chraq_all
character(5),dimension(nsp_gas),intent(in)::chrgas
character(5),dimension(nsp_gas_cnst),intent(in)::chrgas_cnst
character(5),dimension(nsp_gas_all),intent(in)::chrgas_all
real(kind=8),dimension(nsp_aq,nz),intent(in)::maqx
real(kind=8),dimension(nsp_aq_cnst,nz),intent(in)::maqc
real(kind=8),dimension(nsp_gas,nz),intent(in)::mgasx
real(kind=8),dimension(nsp_gas_cnst,nz),intent(in)::mgasc
real(kind=8),dimension(nsp_gas_all,3),intent(in)::keqgas_h
real(kind=8),dimension(nsp_aq_all,4),intent(in)::keqaq_h
real(kind=8),dimension(nsp_aq_all,2),intent(in)::keqaq_c
real(kind=8),dimension(nsp_aq_all,2),intent(in)::keqaq_s
real(kind=8),dimension(nsp_aq_all),intent(in)::maqth_all

integer ieqgas_h0,ieqgas_h1,ieqgas_h2
data ieqgas_h0,ieqgas_h1,ieqgas_h2/1,2,3/

integer ieqaq_h1,ieqaq_h2,ieqaq_h3,ieqaq_h4
data ieqaq_h1,ieqaq_h2,ieqaq_h3,ieqaq_h4/1,2,3,4/

integer ieqaq_co3,ieqaq_hco3
data ieqaq_co3,ieqaq_hco3/1,2/

integer ieqaq_so4,ieqaq_so42
data ieqaq_so4,ieqaq_so42/1,2/

logical,intent(in)::print_cb
character(500),intent(in)::print_loc
logical so4_error

real(kind=8),allocatable::amx(:,:),ymx(:)
integer,allocatable::ipiv(:)
integer info,nmx

external DGESV


error = 1d4
tol = 1d-6
dconc = 1d-14

prox = 1d0 
iter = 0


kco2 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h0)
k1 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h1)
k2 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h2)
k1si = keqaq_h(findloc(chraq_all,'si',dim=1),ieqaq_h1)
k2si = keqaq_h(findloc(chraq_all,'si',dim=1),ieqaq_h2)
k1mg = keqaq_h(findloc(chraq_all,'mg',dim=1),ieqaq_h1)
k1mgco3 = keqaq_c(findloc(chraq_all,'mg',dim=1),ieqaq_co3)
k1mghco3  = keqaq_c(findloc(chraq_all,'mg',dim=1),ieqaq_hco3)
k1ca = keqaq_h(findloc(chraq_all,'ca',dim=1),ieqaq_h1)
k1caco3 = keqaq_c(findloc(chraq_all,'ca',dim=1),ieqaq_co3)
k1cahco3 = keqaq_c(findloc(chraq_all,'ca',dim=1),ieqaq_hco3)
k1al= keqaq_h(findloc(chraq_all,'al',dim=1),ieqaq_h1)
k2al= keqaq_h(findloc(chraq_all,'al',dim=1),ieqaq_h2)
k3al= keqaq_h(findloc(chraq_all,'al',dim=1),ieqaq_h3)
k4al= keqaq_h(findloc(chraq_all,'al',dim=1),ieqaq_h4)
k1fe2 = keqaq_h(findloc(chraq_all,'fe2',dim=1),ieqaq_h1)
k1fe2co3 = keqaq_c(findloc(chraq_all,'fe2',dim=1),ieqaq_co3)
k1fe2hco3  = keqaq_c(findloc(chraq_all,'fe2',dim=1),ieqaq_hco3)
k1fe3= keqaq_h(findloc(chraq_all,'fe3',dim=1),ieqaq_h1)
k2fe3= keqaq_h(findloc(chraq_all,'fe3',dim=1),ieqaq_h2)
k3fe3= keqaq_h(findloc(chraq_all,'fe3',dim=1),ieqaq_h3)
k4fe3= keqaq_h(findloc(chraq_all,'fe3',dim=1),ieqaq_h4)
k1naco3 = keqaq_c(findloc(chraq_all,'na',dim=1),ieqaq_co3)
k1nahco3  = keqaq_c(findloc(chraq_all,'na',dim=1),ieqaq_hco3)

k1so4 = keqaq_h(findloc(chraq_all,'so4',dim=1),ieqaq_h1)
k1naso4 = keqaq_s(findloc(chraq_all,'na',dim=1),ieqaq_so4)
k1kso4 = keqaq_s(findloc(chraq_all,'k',dim=1),ieqaq_so4)
k1caso4 = keqaq_s(findloc(chraq_all,'ca',dim=1),ieqaq_so4)
k1mgso4 = keqaq_s(findloc(chraq_all,'mg',dim=1),ieqaq_so4)
k1fe2so4 = keqaq_s(findloc(chraq_all,'fe2',dim=1),ieqaq_so4)
k1also4 = keqaq_s(findloc(chraq_all,'al',dim=1),ieqaq_so4)
k1fe3so4 = keqaq_s(findloc(chraq_all,'fe3',dim=1),ieqaq_so4)
k1also42 = keqaq_s(findloc(chraq_all,'al',dim=1),ieqaq_so42)
k1fe3so42 = keqaq_s(findloc(chraq_all,'fe3',dim=1),ieqaq_so42)

nax = 0d0
so4x = 0d0
kx = 0d0
if (any(chraq=='na')) then 
    nax = maqx(findloc(chraq,'na',dim=1),:)
elseif (any(chraq_cnst=='na')) then 
    nax = maqc(findloc(chraq_cnst,'na',dim=1),:)
endif 
if (any(chraq=='k')) then 
    kx = maqx(findloc(chraq,'k',dim=1),:)
elseif (any(chraq_cnst=='k')) then 
    kx = maqc(findloc(chraq_cnst,'k',dim=1),:)
endif 
if (any(chraq=='so4')) then 
    so4x = maqx(findloc(chraq,'so4',dim=1),:)
elseif (any(chraq_cnst=='so4')) then 
    so4x = maqc(findloc(chraq_cnst,'so4',dim=1),:)
endif 

! netcat = nax + kx -2d0*so4x
! netcat = kx -2d0*so4x
netcat = 0d0

six =0d0
cax =0d0
mgx =0d0
fe2x =0d0
alx =0d0
fe3x =0d0
pco2x =0d0

if (any(chraq=='si')) then 
    six = maqx(findloc(chraq,'si',dim=1),:)
elseif (any(chraq_cnst=='si')) then 
    six = maqc(findloc(chraq_cnst,'si',dim=1),:)
endif 
if (any(chraq=='ca')) then 
    cax = maqx(findloc(chraq,'ca',dim=1),:)
elseif (any(chraq_cnst=='ca')) then 
    cax = maqc(findloc(chraq_cnst,'ca',dim=1),:)
endif 
if (any(chraq=='mg')) then 
    mgx = maqx(findloc(chraq,'mg',dim=1),:)
elseif (any(chraq_cnst=='mg')) then 
    mgx = maqc(findloc(chraq_cnst,'mg',dim=1),:)
endif 
if (any(chraq=='fe2')) then 
    fe2x = maqx(findloc(chraq,'fe2',dim=1),:)
elseif (any(chraq_cnst=='fe2')) then 
    fe2x = maqc(findloc(chraq_cnst,'fe2',dim=1),:)
endif 
if (any(chraq=='al')) then 
    alx = maqx(findloc(chraq,'al',dim=1),:)
elseif (any(chraq_cnst=='al')) then 
    alx = maqc(findloc(chraq_cnst,'al',dim=1),:)
endif 
if (any(chraq=='fe3')) then 
    fe3x = maqx(findloc(chraq,'fe3',dim=1),:)
elseif (any(chraq_cnst=='fe3')) then 
    fe3x = maqc(findloc(chraq_cnst,'fe3',dim=1),:)
endif 
if (any(chrgas=='pco2')) then 
    pco2x = mgasx(findloc(chrgas,'pco2',dim=1),:)
elseif (any(chrgas_cnst=='pco2')) then 
    pco2x = mgasc(findloc(chrgas_cnst,'pco2',dim=1),:)
endif 

if (any(isnan(maqx)) .or. any(isnan(maqc))) then 
    print*,'nan in input aqueosu species'
    stop
endif 

200 continue


so4th = maqth_all(findloc(chraq_all,'so4',dim=1))

so4f  = so4x 

nmx = 2*nz
! if (all(so4x==0d0)) then 
if (all(so4x<=so4th)) then 
    nmx = nz
endif  

allocate(amx(nmx,nmx),ymx(nmx),ipiv(nmx))

ph_error = .false.

! print*,'calc_pH'
do while (error > tol)
    ! free SO42- (for simplicity only consider XSO4 complex where X is a cation)
    
    kf = kx/(1d0+k1kso4*so4f)
    dkf_dso4f = kx*(-1d0)/(1d0+k1kso4*so4f)**2d0*(k1kso4)
    dkf_dpro = 0d0
    
    naf = nax/(1d0+k1naco3*k1*k2*kco2*pco2x/prox**2d0+k1nahco3*k1*k2*kco2*pco2x/prox+k1naso4*so4f)
    dnaf_dpro = nax*(-1d0)/(1d0+k1naco3*k1*k2*kco2*pco2x/prox**2d0+k1nahco3*k1*k2*kco2*pco2x/prox+k1naso4*so4f)**2d0 &
        & *(k1naco3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0+k1nahco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0)
    dnaf_dso4f = nax*(-1d0)/(1d0+k1naco3*k1*k2*kco2*pco2x/prox**2d0+k1nahco3*k1*k2*kco2*pco2x/prox+k1naso4*so4f)**2d0 &
        & *(k1naso4)
        
    caf = cax/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox+k1caso4*so4f)
    dcaf_dpro = cax*(-1d0)/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox+k1caso4*so4f)**2d0 &
        & *(k1ca*(-1d0)/prox**2d0+k1caco3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0+k1cahco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0)
    dcaf_dso4f = cax*(-1d0)/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox+k1caso4*so4f)**2d0 &
        & *(k1caso4)
        
    mgf = mgx/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox+k1mgso4*so4f)
    dmgf_dpro = mgx*(-1d0)/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox+k1mgso4*so4f)**2d0 &
        & *(k1mg*(-1d0)/prox**2d0+k1mgco3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0+k1mghco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0)
    dmgf_dso4f = mgx*(-1d0)/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox+k1mgso4*so4f)**2d0 &
        & *(k1mgso4)
        
    fe2f = fe2x/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox+k1fe2so4*so4f)
    dfe2f_dpro = fe2x*(-1d0) &
        & /(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox+k1fe2so4*so4f)**2d0 &
        & *(k1fe2*(-1d0)/prox**2d0+k1fe2co3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0+k1fe2hco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0)
    dfe2f_dso4f = fe2x*(-1d0) &
        & /(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox+k1fe2so4*so4f)**2d0 &
        & *(k1fe2so4)
        
    sif = six/(1d0+k1si/prox+k2si/prox**2d0)
    dsif_dpro = six*(-1d0)/(k1si*(-1d0)/prox**2d0+k2si*(-2d0)/prox**3d0)
    dsif_dso4f = 0d0
    
    alf = alx/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0+k1also4*so4f)
    dalf_dpro = alx*(-1d0)/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0+k1also4*so4f)**2d0 &
        & *(k1al*(-1d0)/prox**2d0+k2al*(-2d0)/prox**3d0+k3al*(-3d0)/prox**4d0+k4al*(-4d0)/prox**5d0)
    dalf_dso4f = alx*(-1d0)/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0+k1also4*so4f)**2d0 &
        & *(k1also4)
    
    fe3f = fe3x/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0+k1fe3so4*so4f)
    dfe3f_dpro = fe3x*(-1d0)/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0+k1fe3so4*so4f)**2d0 &
        & *(k1fe3*(-1d0)/prox**2d0+k2fe3*(-2d0)/prox**3d0+k3fe3*(-3d0)/prox**4d0+k4fe3*(-4d0)/prox**5d0)
    dfe3f_dso4f = fe3x*(-1d0)/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0+k1fe3so4*so4f)**2d0 &
        & *(k1fe3so4)
    
    f1 = prox**5d0 + netcat*prox**4d0 - (k1*kco2*pco2x+kw)*prox**3d0 - 2d0*k2*k1*kco2*pco2x*prox**2d0  &
        ! so4
        & -2d0*so4f*prox**4d0 &
        & -1d0*so4f*prox**5d0*k1so4 &
        ! k
        & + kf*prox**4d0 &
        & - kf*prox**4d0*k1kso4*so4f &
        ! na
        & + naf*prox**4d0 &
        & -1d0*naf*k1naco3*k1*k2*kco2*pco2x*prox**2d0  &
        & -1d0*naf*prox**4d0*k1naso4*so4f  &
        ! si 
        & - sif*k1si*prox**3d0 &
        & - 2d0*sif*k2si*prox**2d0 &
        ! mg
        & + 2d0*mgf*prox**4d0 &
        & + mgf*k1mg*prox**3d0 &
        & + mgf*k1mghco3*k1*k2*kco2*pco2x*prox**3d0  &
        ! ca
        & + 2d0*caf*prox**4d0 &
        & + caf*k1ca*prox**3d0 &
        & + caf*k1cahco3*k1*k2*kco2*pco2x*prox**3d0 &
        ! al
        & + 3d0*alf*prox**4d0 &
        & + 2d0*alf*k1al*prox**3d0 &
        & + alf*k2al*prox**2d0 &
        & - alf*k4al &
        & + alf*k1also4*so4f*prox**4d0 &
        ! fe2
        & + 2d0*fe2f*prox**4d0 &
        & + fe2f*k1fe2*prox**3d0 &
        & + fe2f*k1fe2hco3*k1*k2*kco2*pco2x*prox**3d0 &
        ! fe3
        & + 3d0*fe3f*prox**4d0 &
        & + 2d0*fe3f*k1fe3*prox**3d0 &
        & + fe3f*k2fe3*prox**2d0 &
        & - fe3f*k4fe3 &
        & + fe3f*k1fe3so4*so4f*prox**4d0 
        
    df1 = 5d0*prox**4d0 + 4d0*netcat*prox**3d0 - (k1*kco2*pco2x+kw)*3d0*prox**2d0 - 2d0*k2*k1*kco2*pco2x*prox*2d0 &
        !
        ! so4
        & -2d0*so4f*4d0*prox**3d0 &
        & -1d0*so4f*5d0*prox**4d0*k1so4 &
        !
        ! k
        & + dkf_dpro*prox**4d0 &
        & + kf*4d0*prox**3d0 &
        & - dkf_dpro*prox**4d0*k1kso4*so4f &
        & - kf*4d0*prox**3d0*k1kso4*so4f &
        !
        ! na
        & + dnaf_dpro*prox**4d0 &
        & + naf*4d0*prox**3d0 &
        & -1d0*dnaf_dpro*k1naco3*k1*k2*kco2*pco2x*prox**2d0  &
        & -1d0*naf*k1naco3*k1*k2*kco2*pco2x*prox*2d0  &
        & -1d0*dnaf_dpro*prox**4d0*k1naso4*so4f  &
        & -1d0*naf*4d0*prox**3d0*k1naso4*so4f  &
        !
        ! si
        !
        & - dsif_dpro*k1si*prox**3d0 &
        & - sif*k1si*3d0*prox**2d0 &
        & - 2d0*dsif_dpro*k2si*prox**2d0 &
        & - 2d0*sif*k2si*prox*2d0 &
        !
        ! mg
        !
        & + 2d0*dmgf_dpro*prox**4d0 &
        & + 2d0*mgf*4d0*prox**3d0 &
        & + dmgf_dpro*k1mg*prox**3d0 &
        & + mgf*k1mg*3d0*prox**2d0 &
        & + dmgf_dpro*k1mghco3*k1*k2*kco2*pco2x*prox**3d0  &
        & + mgf*k1mghco3*k1*k2*kco2*pco2x*3d0*prox**2d0  &
        ! 
        ! ca
        !
        & + 2d0*dcaf_dpro*prox**4d0 &
        & + 2d0*caf*4d0*prox**3d0 &
        & + dcaf_dpro*k1ca*prox**3d0 &
        & + caf*k1ca*3d0*prox**2d0 &
        & + dcaf_dpro*k1cahco3*k1*k2*kco2*pco2x*prox**3d0  &
        & + caf*k1cahco3*k1*k2*kco2*pco2x*3d0*prox**2d0  &
        !
        ! al
        !
        & + 3d0*dalf_dpro*prox**4d0 &
        & + 3d0*alf*4d0*prox**3d0 &
        & + 2d0*dalf_dpro*k1al*prox**3d0 &
        & + 2d0*alf*k1al*3d0*prox**2d0 &
        & + dalf_dpro*k2al*prox**2d0 &
        & + alf*k2al*prox*2d0 &
        & - dalf_dpro*k4al &
        & + dalf_dpro*k1also4*so4f*prox**4d0 &
        & + alf*k1also4*so4f*4d0*prox**3d0 &
        !
        ! fe2
        ! 
        & + 2d0*dfe2f_dpro*prox**4d0 &
        & + 2d0*fe2f*4d0*prox**3d0 &
        & + dfe2f_dpro*k1fe2*prox**3d0 &
        & + fe2f*k1fe2*3d0*prox**2d0 &
        & + dfe2f_dpro*k1fe2hco3*k1*k2*kco2*pco2x*prox**3d0  &
        & + fe2f*k1fe2hco3*k1*k2*kco2*pco2x*3d0*prox**2d0  &
        !
        ! fe3 
        !
        & + 3d0*dfe3f_dpro*prox**4d0 &
        & + 3d0*fe3f*4d0*prox**3d0 &
        & + 2d0*dfe3f_dpro*k1fe3*prox**3d0 &
        & + 2d0*fe3f*k1fe3*3d0*prox**2d0 &
        & + dfe3f_dpro*k2fe3*prox**2d0 &
        & + fe3f*k2fe3*prox*2d0 &
        & - dfe3f_dpro*k4fe3 &
        & + dfe3f_dpro*k1fe3so4*so4f*prox**4d0 &
        & + fe3f*k1fe3so4*so4f*4d0*prox**3d0 
    
    df12 =   &
        ! so4
        & -2d0*1d0*prox**4d0 &
        & -1d0*1d0*prox**5d0*k1so4 &
        ! k
        & + dkf_dso4f*prox**4d0 &
        & - dkf_dso4f*prox**4d0*k1kso4*so4f &
        & - kf*prox**4d0*k1kso4*1d0 &
        ! na
        & + dnaf_dso4f*prox**4d0 &
        & -1d0*dnaf_dso4f*k1naco3*k1*k2*kco2*pco2x*prox**2d0  &
        & -1d0*dnaf_dso4f*prox**4d0*k1naso4*so4f  &
        & -1d0*naf*prox**4d0*k1naso4*1d0  &
        ! si 
        & - dsif_dso4f*k1si*prox**3d0 &
        & - 2d0*dsif_dso4f*k2si*prox**2d0 &
        ! mg
        & + 2d0*dmgf_dso4f*prox**4d0 &
        & + dmgf_dso4f*k1mg*prox**3d0 &
        & + dmgf_dso4f*k1mghco3*k1*k2*kco2*pco2x*prox**3d0  &
        ! ca
        & + 2d0*dcaf_dso4f*prox**4d0 &
        & + dcaf_dso4f*k1ca*prox**3d0 &
        & + dcaf_dso4f*k1cahco3*k1*k2*kco2*pco2x*prox**3d0 &
        ! al
        & + 3d0*dalf_dso4f*prox**4d0 &
        & + 2d0*dalf_dso4f*k1al*prox**3d0 &
        & + dalf_dso4f*k2al*prox**2d0 &
        & - dalf_dso4f*k4al &
        & + dalf_dso4f*k1also4*so4f*prox**4d0 &
        & + alf*k1also4*1d0*prox**4d0 &
        ! fe2
        & + 2d0*dfe2f_dso4f*prox**4d0 &
        & + dfe2f_dso4f*k1fe2*prox**3d0 &
        & + dfe2f_dso4f*k1fe2hco3*k1*k2*kco2*pco2x*prox**3d0 &
        ! fe3
        & + 3d0*dfe3f_dso4f*prox**4d0 &
        & + 2d0*dfe3f_dso4f*k1fe3*prox**3d0 &
        & + dfe3f_dso4f*k2fe3*prox**2d0 &
        & - dfe3f_dso4f*k4fe3 &
        & + dfe3f_dso4f*k1fe3so4*so4f*prox**4d0 &
        & + fe3f*k1fe3so4*1d0*prox**4d0 
        
        
        
    
    f2 = prox**4d0*so4x - prox**4d0*so4f*( 1d0+k1so4*prox &
        & +k1kso4*kf &
        & +k1naso4*naf &
        & +k1caso4*caf &
        & +k1mgso4*mgf &
        & +k1fe2so4*fe2f &
        & +k1also4*alf &
        & +k1fe3so4*fe3f &
        & )
        
    df2 =  - prox**4d0*1d0*( 1d0+k1so4*prox &
        & +k1kso4*kf &
        & +k1naso4*naf &
        & +k1caso4*caf &
        & +k1mgso4*mgf &
        & +k1fe2so4*fe2f &
        & +k1also4*alf &
        & +k1fe3so4*fe3f &
        & ) &
        & - prox**4d0*so4f*(  &
        & +k1kso4*dkf_dso4f &
        & +k1naso4*dnaf_dso4f &
        & +k1caso4*dcaf_dso4f &
        & +k1mgso4*dmgf_dso4f &
        & +k1fe2so4*dfe2f_dso4f &
        & +k1also4*dalf_dso4f &
        & +k1fe3so4*dfe3f_dso4f &
        & )
        
    df21 = 4d0*prox**3d0*so4x- prox**4d0*so4f*( k1so4*1d0 &
        & +k1kso4*dkf_dpro &
        & +k1naso4*dnaf_dpro &
        & +k1caso4*dcaf_dpro &
        & +k1mgso4*dmgf_dpro &
        & +k1fe2so4*dfe2f_dpro &
        & +k1also4*dalf_dpro &
        & +k1fe3so4*dfe3f_dpro &
        & ) &
        & -4d0*prox**3d0*so4f*( 1d0+k1so4*prox &
        & +k1kso4*kf &
        & +k1naso4*naf &
        & +k1caso4*caf &
        & +k1mgso4*mgf &
        & +k1fe2so4*fe2f &
        & +k1also4*alf &
        & +k1fe3so4*fe3f &
        & )
        
        
        
    df1 = df1*prox
    df21 = df21*prox
    df2 = df2*so4f
    df12 = df12*so4f
    
    if (any(isnan(f1)).or.any(isnan(f2)).or.any(isnan(df1)).or.any(isnan(df2)) &
        & .or.any(isnan(df12)).or.any(isnan(df21))) then 
        print *,any(isnan(f1)),any(isnan(f2)),any(isnan(df1)),any(isnan(df2)) &
            & ,any(isnan(df12)),any(isnan(df21))
        print *,prox
        ! pause 
    endif 
    
    
    if (nmx/=nz) then 
        amx = 0d0
        ymx = 0d0
        
        ymx(1:nz) = f1
        ymx(nz+1:nmx) = f2
        
        do iz=1,nz
            amx(iz,iz)=df1(iz)
            amx(nz+iz,nz+iz)=df2(iz)
            amx(iz,nz+iz)=df12(iz)
            amx(nz+iz,iz)=df21(iz)
        enddo 
        ymx = -ymx
        
        call DGESV(nmx,int(1),amx,nmx,ipiv,ymx,nmx,info) 
        
        prox = prox*exp( ymx(1:nz) )
        so4f = so4f*exp( ymx(nz+1:nmx) )
        
        error = maxval(abs(exp( ymx )-1d0))
        if (isnan(error)) then 
            error = 1d4
            ph_error = .true.
            exit 
        endif 
    else 
        prox = prox*exp( -f1/df1 )
        error = maxval(abs(exp( -f1/df1 )-1d0))
        if (isnan(error)) error = 1d4
    endif 
    
    iter = iter + 1
    if (iter > 1000) then 
        print *,'iteration exceeds 1000'
        ph_error = .true.
        exit
    endif 
enddo 
if (any(isnan(prox))) then     
    print *, (-log10(prox(iz)),iz=1,nz,nz/5)
    print*,'ph is nan'
    ph_error = .true.
    ! stop
endif 

    
kf = kx/(1d0+k1kso4*so4f)

naf = nax/(1d0+k1naco3*k1*k2*kco2*pco2x/prox**2d0+k1nahco3*k1*k2*kco2*pco2x/prox+k1naso4*so4f)
    
caf = cax/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox+k1caso4*so4f)
    
mgf = mgx/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox+k1mgso4*so4f)
    
fe2f = fe2x/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox+k1fe2so4*so4f)
    
sif = six/(1d0+k1si/prox+k2si/prox**2d0)

alf = alx/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0+k1also4*so4f)

fe3f = fe3x/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0+k1fe3so4*so4f)

if (print_cb) then 
    open(88,file = trim(adjustl(print_loc)),status='replace')
    write(88,*) ' z ',' h+ ',' oh- ',' na+ ',' naco3- ', ' nahco3 ', ' naso4- ', ' k+ ',' kso4- ' &
        & ,' so42- ', ' hso4- ', 'hco3- ', ' co32- ' &
        & ,' h4sio4 ',' h3sio4- ',' h2sio42- ' &
        & ,' mg2+ ', ' mg(oh)+ ', ' mgco3 ', 'mghco3+ ', 'mgso4 ' &
        & , ' ca2+ ', ' ca(oh)+ ', ' caco3 ', ' cahco3+ ', ' caso4 ' &
        & ,' al3+ ', ' al(oh)2+ ', ' al(oh)2+ ', ' al(oh)3 ', ' al(oh)4- ' , ' also4+ ' &
        & , ' fe22+ ', ' fe2(oh)+ ', ' fe2co3 ', ' fe2hco3+ ', ' fe2so4 ' &
        & ,' fe3+ ', ' fe3(oh)2+ ', ' fe3(oh)2+ ', ' fe3(oh)3 ', ' fe3(oh)4- ', ' fe3so4+ ' &
        & , ' total_charge ' 
    do iz=1,nz
        write(88,*) z(iz) &
        & ,prox(iz) &
        & ,kw/prox(iz) &
        & ,naf(iz) &
        & ,naf(iz)*k1naco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0 &
        & ,naf(iz)*k1nahco3*k1*k2*kco2*pco2x(iz)/prox(iz)     &
        & ,naf(iz)*k1naso4*so4f(iz)     &
        & ,kf(iz) &
        & ,kf(iz)*k1kso4*so4f(iz) &
        & ,so4f(iz) &
        & ,so4f(iz)*k1so4*prox(iz) &
        & ,k1*kco2*pco2x(iz)/prox(iz) &
        & ,k2*k1*kco2*pco2x(iz)/prox(iz)**2d0 &
        & ,sif(iz) &
        & ,sif(iz)*k1si/prox(iz) &
        & ,sif(iz)*k2si/prox(iz)**2d0 &
        & ,mgf(iz) &
        & ,mgf(iz)*k1mg/prox(iz)  &
        & ,mgf(iz)*k1mgco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0  &
        & ,mgf(iz)*k1mghco3*k1*k2*kco2*pco2x(iz)/prox(iz)  &
        & ,mgf(iz)*k1mgso4*so4f(iz)  &
        & ,caf(iz) &
        & ,caf(iz)*k1ca/prox(iz) &
        & ,caf(iz)*k1caco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0 &
        & ,caf(iz)*k1cahco3*k1*k2*kco2*pco2x(iz)/prox(iz) &
        & ,caf(iz)*k1caso4*so4f(iz) &
        & ,alf(iz) &
        & ,alf(iz)*k1al/prox(iz) &
        & ,alf(iz)*k2al/prox(iz)**2d0 &
        & ,alf(iz)*k3al/prox(iz)**3d0 &
        & ,alf(iz)*k4al/prox(iz)**4d0 &
        & ,alf(iz)*k1also4*so4f(iz) &
        & ,fe2f(iz) &
        & ,fe2f(iz)*k1fe2/prox(iz) &
        & ,fe2f(iz)*k1fe2co3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0 &
        & ,fe2f(iz)*k1fe2hco3*k1*k2*kco2*pco2x(iz)/prox(iz) &
        & ,fe2f(iz)*k1fe2so4*so4f(iz) &
        & ,fe3f(iz) &
        & ,fe3f(iz)*k1fe3/prox(iz) &
        & ,fe3f(iz)*k2fe3/prox(iz)**2d0 &
        & ,fe3f(iz)*k3fe3/prox(iz)**3d0 &
        & ,fe3f(iz)*k4fe3/prox(iz)**4d0 &
        & ,fe3f(iz)*k1fe3so4*so4f(iz) &
        ! charge balance 
        & ,1d0*prox(iz) &
        & +(-1d0)*kw/prox(iz) &
        & +(1d0)*naf(iz) &
        & +(-1d0)*naf(iz)*k1naco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0 &
        & +(0d0)*naf(iz)*k1nahco3*k1*k2*kco2*pco2x(iz)/prox(iz)      &
        & +(-1d0)*naf(iz)*k1naso4*so4f(iz)     &
        & +(1d0)*kf(iz) &
        & +(-1d0)*kf(iz)*k1kso4*so4f(iz) &
        & +(-2d0)*so4f(iz) &
        & +(-1d0)*so4f(iz)*k1so4*prox(iz) &
        & +(-1d0)*k1*kco2*pco2x(iz)/prox(iz) &
        & +(-2d0)*k2*k1*kco2*pco2x(iz)/prox(iz)**2d0 &
        & +(0d0)*sif(iz) &
        & +(-1d0)*sif(iz)*k1si/prox(iz) &
        & +(-2d0)*sif(iz)*k2si/prox(iz)**2d0 &
        & +(2d0)*mgf(iz) &
        & +(1d0)*mgf(iz)*k1mg/prox(iz)  &
        & +(0d0)*mgf(iz)*k1mgco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0  &
        & +(1d0)*mgf(iz)*k1mghco3*k1*k2*kco2*pco2x(iz)/prox(iz)  &
        & +(0d0)*mgf(iz)*k1mgso4*so4f(iz)  &
        & +(2d0)*caf(iz) &
        & +(1d0)*caf(iz)*k1ca/prox(iz) &
        & +(0d0)*caf(iz)*k1caco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0 &
        & +(1d0)*caf(iz)*k1cahco3*k1*k2*kco2*pco2x(iz)/prox(iz) &
        & +(0d0)*caf(iz)*k1caso4*so4f(iz) &
        & +(3d0)*alf(iz) &
        & +(2d0)*alf(iz)*k1al/prox(iz) &
        & +(1d0)*alf(iz)*k2al/prox(iz)**2d0 &
        & +(0d0)*alf(iz)*k3al/prox(iz)**3d0 &
        & +(-1d0)*alf(iz)*k4al/prox(iz)**4d0 &
        & +(1d0)*alf(iz)*k1also4*so4f(iz) &
        & +(2d0)*fe2f(iz) &
        & +(1d0)*fe2f(iz)*k1fe2/prox(iz) &
        & +(0d0)*fe2f(iz)*k1fe2co3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0 &
        & +(1d0)*fe2f(iz)*k1fe2hco3*k1*k2*kco2*pco2x(iz)/prox(iz) &
        & +(0d0)*fe2f(iz)*k1fe2so4*so4f(iz) &
        & +(3d0)*fe3f(iz) &
        & +(2d0)*fe3f(iz)*k1fe3/prox(iz) &
        & +(1d0)*fe3f(iz)*k2fe3/prox(iz)**2d0 &
        & +(0d0)*fe3f(iz)*k3fe3/prox(iz)**3d0 &
        & +(-1d0)*fe3f(iz)*k4fe3/prox(iz)**4d0 &
        & +(1d0)*fe3f(iz)*k1fe3so4*so4f(iz) 
    enddo 
    close(88)
endif 
            

endsubroutine calc_pH_v7

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine calc_pH_v7_2( &
    & nz,kw,nsp_aq,nsp_gas,nsp_aq_all,nsp_gas_all,nsp_aq_cnst,nsp_gas_cnst &! input 
    & ,chraq,chraq_cnst,chraq_all,chrgas,chrgas_cnst,chrgas_all &!input
    & ,maqx,maqc,mgasx,mgasc,keqgas_h,keqaq_h,keqaq_c,keqaq_s,maqth_all,keqaq_no3,keqaq_nh3 &! input
    & ,print_cb,print_loc,z &! input 
    & ,prox,ph_error,so4f,ph_iter &! output
    & ) 
! solving charge balance:
! [H+] + ZX[Xz+] - ZY[YZ-] - [HCO3-] - 2[CO32-] - [OH-] - [H3SiO4-] - 2[H2SiO42-] = 0
! [H+] + ZX[Xz+] - ZY[YZ-] - k1kco2pCO2/[H+] - 2k2k1kco2pCO2/[H+]^2 - kw/[H+] - [Si]/([H+]/k1si + 1 + k2si/k1si/[H+])
!       - 2[Si]/([H+]^2/k2si + [H+]k1si/k2si + 1) = 0
! [H+]^3 + (ZX[Xz+] - ZY[YZ-])[H+]^2 - (k1kco2pCO2+kw)[H+] - 2k2k1kco2pCO2  = 0
! NetCat is defined as (ZX[Xz+] - ZY[YZ-])
! [H+]^3 + NetCat[H+]^2 - (k1kco2pCO2+kw)[H+] - 2k2k1kco2pCO2  = 0
implicit none
integer,intent(in)::nz
real(kind=8),intent(in)::kw
real(kind=8) kco2,k1,k2,k1si,k2si,k1mg,k1mgco3,k1mghco3,k1ca,k1caco3,k1cahco3,k1al,k2al,k3al,k4al &
    & ,k1fe2,k1fe2co3,k1fe2hco3,k1fe3,k2fe3,k3fe3,k4fe3,k1naco3,k1nahco3,k1so4,k1kso4,k1naso4  &
    & ,k1caso4,k1mgso4,k1fe2so4,k1also4,k1also42,k1fe3so4,k1fe3so42,so4th,knh3,k1nh3,k1no3
real(kind=8),dimension(nz)::nax,mgx,cax,so4x,pco2x,six,alx,fe2x,fe3x,kx,no3x,pnh3x
real(kind=8),dimension(nz)::naf,kf,mgf,caf,fe2f,fe3f,alf,sif,no3f
real(kind=8),dimension(nz)::dnaf_dpro,dkf_dpro,dmgf_dpro,dcaf_dpro,dfe2f_dpro,dfe3f_dpro,dalf_dpro,dsif_dpro,dno3f_dpro
real(kind=8),dimension(nz)::dnaf_dso4f,dkf_dso4f,dmgf_dso4f,dcaf_dso4f,dfe2f_dso4f,dfe3f_dso4f,dalf_dso4f,dsif_dso4f &
    & ,dno3f_dso4f
real(kind=8),dimension(nz),intent(in)::z
real(kind=8),dimension(nz),intent(inout)::prox,so4f
logical,intent(out)::ph_error

real(kind=8),dimension(nz)::df1,f1,f2,df2,df21,df12
real(kind=8) error,tol,dconc
integer iter,iz

integer,intent(in)::nsp_aq,nsp_gas,nsp_aq_all,nsp_gas_all,nsp_aq_cnst,nsp_gas_cnst
character(5),dimension(nsp_aq),intent(in)::chraq
character(5),dimension(nsp_aq_cnst),intent(in)::chraq_cnst
character(5),dimension(nsp_aq_all),intent(in)::chraq_all
character(5),dimension(nsp_gas),intent(in)::chrgas
character(5),dimension(nsp_gas_cnst),intent(in)::chrgas_cnst
character(5),dimension(nsp_gas_all),intent(in)::chrgas_all
real(kind=8),dimension(nsp_aq,nz),intent(in)::maqx
real(kind=8),dimension(nsp_aq_cnst,nz),intent(in)::maqc
real(kind=8),dimension(nsp_gas,nz),intent(in)::mgasx
real(kind=8),dimension(nsp_gas_cnst,nz),intent(in)::mgasc
real(kind=8),dimension(nsp_gas_all,3),intent(in)::keqgas_h
real(kind=8),dimension(nsp_aq_all,4),intent(in)::keqaq_h
real(kind=8),dimension(nsp_aq_all,2),intent(in)::keqaq_c
real(kind=8),dimension(nsp_aq_all,2),intent(in)::keqaq_s
real(kind=8),dimension(nsp_aq_all,2),intent(in)::keqaq_nh3
real(kind=8),dimension(nsp_aq_all,2),intent(in)::keqaq_no3
real(kind=8),dimension(nsp_aq_all),intent(in)::maqth_all

integer,intent(out)::ph_iter

real(kind=8),dimension(nsp_aq_all,nz)::maqx_loc,maqf_loc
real(kind=8),dimension(nsp_aq_all,nz)::dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2
real(kind=8),dimension(nsp_gas_all,nz)::mgasx_loc
real(kind=8),dimension(nsp_aq_all,nz)::df1dmaq,df2dmaq
real(kind=8),dimension(nsp_gas_all,nz)::df1dmgas,df2dmgas

real(kind=8),dimension(nz)::f1_dum,f2_dum,df1_dum,df2_dum,df12_dum,df21_dum

real(kind=8)::ph_add_order = 2d0
logical print_res 
real(kind=8) diff_max

integer ieqgas_h0,ieqgas_h1,ieqgas_h2
data ieqgas_h0,ieqgas_h1,ieqgas_h2/1,2,3/

integer ieqaq_h1,ieqaq_h2,ieqaq_h3,ieqaq_h4
data ieqaq_h1,ieqaq_h2,ieqaq_h3,ieqaq_h4/1,2,3,4/

integer ieqaq_co3,ieqaq_hco3
data ieqaq_co3,ieqaq_hco3/1,2/

integer ieqaq_so4,ieqaq_so42
data ieqaq_so4,ieqaq_so42/1,2/

integer ieqaq_no3,ieqaq_no32
data ieqaq_no3,ieqaq_no32/1,2/

logical,intent(in)::print_cb
character(500),intent(in)::print_loc
logical so4_error

real(kind=8),allocatable::amx(:,:),ymx(:)
integer,allocatable::ipiv(:)
integer info,nmx

! external DGESV
#ifdef timing
real(kind=8) :: t1, t2
#endif 

print_res = print_cb

error = 1d4
tol = 1d-6
dconc = 1d-14

prox = 1d0 
iter = 0


kco2 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h0)
k1 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h1)
k2 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h2)
k1si = keqaq_h(findloc(chraq_all,'si',dim=1),ieqaq_h1)
k2si = keqaq_h(findloc(chraq_all,'si',dim=1),ieqaq_h2)
k1mg = keqaq_h(findloc(chraq_all,'mg',dim=1),ieqaq_h1)
k1mgco3 = keqaq_c(findloc(chraq_all,'mg',dim=1),ieqaq_co3)
k1mghco3  = keqaq_c(findloc(chraq_all,'mg',dim=1),ieqaq_hco3)
k1ca = keqaq_h(findloc(chraq_all,'ca',dim=1),ieqaq_h1)
k1caco3 = keqaq_c(findloc(chraq_all,'ca',dim=1),ieqaq_co3)
k1cahco3 = keqaq_c(findloc(chraq_all,'ca',dim=1),ieqaq_hco3)
k1al= keqaq_h(findloc(chraq_all,'al',dim=1),ieqaq_h1)
k2al= keqaq_h(findloc(chraq_all,'al',dim=1),ieqaq_h2)
k3al= keqaq_h(findloc(chraq_all,'al',dim=1),ieqaq_h3)
k4al= keqaq_h(findloc(chraq_all,'al',dim=1),ieqaq_h4)
k1fe2 = keqaq_h(findloc(chraq_all,'fe2',dim=1),ieqaq_h1)
k1fe2co3 = keqaq_c(findloc(chraq_all,'fe2',dim=1),ieqaq_co3)
k1fe2hco3  = keqaq_c(findloc(chraq_all,'fe2',dim=1),ieqaq_hco3)
k1fe3= keqaq_h(findloc(chraq_all,'fe3',dim=1),ieqaq_h1)
k2fe3= keqaq_h(findloc(chraq_all,'fe3',dim=1),ieqaq_h2)
k3fe3= keqaq_h(findloc(chraq_all,'fe3',dim=1),ieqaq_h3)
k4fe3= keqaq_h(findloc(chraq_all,'fe3',dim=1),ieqaq_h4)
k1naco3 = keqaq_c(findloc(chraq_all,'na',dim=1),ieqaq_co3)
k1nahco3  = keqaq_c(findloc(chraq_all,'na',dim=1),ieqaq_hco3)

k1so4 = keqaq_h(findloc(chraq_all,'so4',dim=1),ieqaq_h1)
k1naso4 = keqaq_s(findloc(chraq_all,'na',dim=1),ieqaq_so4)
k1kso4 = keqaq_s(findloc(chraq_all,'k',dim=1),ieqaq_so4)
k1caso4 = keqaq_s(findloc(chraq_all,'ca',dim=1),ieqaq_so4)
k1mgso4 = keqaq_s(findloc(chraq_all,'mg',dim=1),ieqaq_so4)
k1fe2so4 = keqaq_s(findloc(chraq_all,'fe2',dim=1),ieqaq_so4)
k1also4 = keqaq_s(findloc(chraq_all,'al',dim=1),ieqaq_so4)
k1fe3so4 = keqaq_s(findloc(chraq_all,'fe3',dim=1),ieqaq_so4)
k1also42 = keqaq_s(findloc(chraq_all,'al',dim=1),ieqaq_so42)
k1fe3so42 = keqaq_s(findloc(chraq_all,'fe3',dim=1),ieqaq_so42)

knh3 = keqgas_h(findloc(chrgas_all,'pnh3',dim=1),ieqgas_h0)
k1nh3 = keqgas_h(findloc(chrgas_all,'pnh3',dim=1),ieqgas_h1)

k1no3 = keqaq_h(findloc(chraq_all,'no3',dim=1),ieqaq_h1)

nax = 0d0
so4x = 0d0
kx = 0d0
no3x = 0d0
if (any(chraq=='na')) then 
    nax = maqx(findloc(chraq,'na',dim=1),:)
elseif (any(chraq_cnst=='na')) then 
    nax = maqc(findloc(chraq_cnst,'na',dim=1),:)
endif 
if (any(chraq=='k')) then 
    kx = maqx(findloc(chraq,'k',dim=1),:)
elseif (any(chraq_cnst=='k')) then 
    kx = maqc(findloc(chraq_cnst,'k',dim=1),:)
endif 
if (any(chraq=='so4')) then 
    so4x = maqx(findloc(chraq,'so4',dim=1),:)
elseif (any(chraq_cnst=='so4')) then 
    so4x = maqc(findloc(chraq_cnst,'so4',dim=1),:)
endif 
if (any(chraq=='no3')) then 
    no3x = maqx(findloc(chraq,'no3',dim=1),:)
elseif (any(chraq_cnst=='no3')) then 
    no3x = maqc(findloc(chraq_cnst,'no3',dim=1),:)
endif 


six =0d0
cax =0d0
mgx =0d0
fe2x =0d0
alx =0d0
fe3x =0d0
pco2x =0d0
pnh3x =0d0

if (any(chraq=='si')) then 
    six = maqx(findloc(chraq,'si',dim=1),:)
elseif (any(chraq_cnst=='si')) then 
    six = maqc(findloc(chraq_cnst,'si',dim=1),:)
endif 
if (any(chraq=='ca')) then 
    cax = maqx(findloc(chraq,'ca',dim=1),:)
elseif (any(chraq_cnst=='ca')) then 
    cax = maqc(findloc(chraq_cnst,'ca',dim=1),:)
endif 
if (any(chraq=='mg')) then 
    mgx = maqx(findloc(chraq,'mg',dim=1),:)
elseif (any(chraq_cnst=='mg')) then 
    mgx = maqc(findloc(chraq_cnst,'mg',dim=1),:)
endif 
if (any(chraq=='fe2')) then 
    fe2x = maqx(findloc(chraq,'fe2',dim=1),:)
elseif (any(chraq_cnst=='fe2')) then 
    fe2x = maqc(findloc(chraq_cnst,'fe2',dim=1),:)
endif 
if (any(chraq=='al')) then 
    alx = maqx(findloc(chraq,'al',dim=1),:)
elseif (any(chraq_cnst=='al')) then 
    alx = maqc(findloc(chraq_cnst,'al',dim=1),:)
endif 
if (any(chraq=='fe3')) then 
    fe3x = maqx(findloc(chraq,'fe3',dim=1),:)
elseif (any(chraq_cnst=='fe3')) then 
    fe3x = maqc(findloc(chraq_cnst,'fe3',dim=1),:)
endif 
if (any(chrgas=='pco2')) then 
    pco2x = mgasx(findloc(chrgas,'pco2',dim=1),:)
elseif (any(chrgas_cnst=='pco2')) then 
    pco2x = mgasc(findloc(chrgas_cnst,'pco2',dim=1),:)
endif 
if (any(chrgas=='pnh3')) then 
    pnh3x = mgasx(findloc(chrgas,'pnh3',dim=1),:)
elseif (any(chrgas_cnst=='pnh3')) then 
    pnh3x = mgasc(findloc(chrgas_cnst,'pnh3',dim=1),:)
endif 

if (any(isnan(maqx)) .or. any(isnan(maqc))) then 
    print*,'nan in input aqueosu species'
    stop
endif 

200 continue


#ifdef debug
call get_maqgasx_all( &
    & nz,nsp_aq_all,nsp_gas_all,nsp_aq,nsp_gas,nsp_aq_cnst,nsp_gas_cnst &
    & ,chraq,chraq_all,chraq_cnst,chrgas,chrgas_all,chrgas_cnst &
    & ,maqx,mgasx,maqc,mgasc &
    & ,maqx_loc,mgasx_loc  &! output
    & )
! print *
! print * , 'na',maxval(abs(nax - maqx_loc(findloc(chraq_all,'na',dim=1),:)))
! print * , 'k',maxval(abs(kx - maqx_loc(findloc(chraq_all,'k',dim=1),:)))
! print * , 'so4',maxval(abs(so4x - maqx_loc(findloc(chraq_all,'so4',dim=1),:)))
! print * , 'no3',maxval(abs(no3x - maqx_loc(findloc(chraq_all,'no3',dim=1),:)))
! print * , 'si',maxval(abs(six - maqx_loc(findloc(chraq_all,'si',dim=1),:)))
! print * , 'ca',maxval(abs(cax - maqx_loc(findloc(chraq_all,'ca',dim=1),:)))
! print * , 'mg',maxval(abs(mgx - maqx_loc(findloc(chraq_all,'mg',dim=1),:)))
! print * , 'fe2',maxval(abs(fe2x - maqx_loc(findloc(chraq_all,'fe2',dim=1),:)))
! print * , 'al',maxval(abs(alx - maqx_loc(findloc(chraq_all,'al',dim=1),:)))
! print * , 'fe3',maxval(abs(fe3x - maqx_loc(findloc(chraq_all,'fe3',dim=1),:)))
! print * , 'pco2',maxval(abs(pco2x - mgasx_loc(findloc(chrgas_all,'pco2',dim=1),:)))
! print * , 'pnh3',maxval(abs(pnh3x - mgasx_loc(findloc(chrgas_all,'pnh3',dim=1),:)))
! print *
#endif 

so4th = maqth_all(findloc(chraq_all,'so4',dim=1))

so4f  = so4x 

nmx = 2*nz
! if (all(so4x==0d0)) then 
if (all(so4x<=so4th)) then 
    nmx = nz
#ifdef debug
    print *, 'v7_2 so4f is assumed to be constant'
#endif 
endif  

allocate(amx(nmx,nmx),ymx(nmx),ipiv(nmx))

ph_error = .false.

#ifdef debug
    print *, 'v7_2 nmx = :',nmx
#endif 
! print*,'calc_pH'
#ifdef timing
call cpu_time( t1 )
#endif 
do while (error > tol)
    ! free SO42- (for simplicity only consider XSO4 complex where X is a cation)
    
    kf = kx/(1d0+k1kso4*so4f)
    dkf_dso4f = kx*(-1d0)/(1d0+k1kso4*so4f)**2d0*(k1kso4)
    dkf_dpro = 0d0
    
    naf = nax/(1d0+k1naco3*k1*k2*kco2*pco2x/prox**2d0+k1nahco3*k1*k2*kco2*pco2x/prox+k1naso4*so4f)
    dnaf_dpro = nax*(-1d0)/(1d0+k1naco3*k1*k2*kco2*pco2x/prox**2d0+k1nahco3*k1*k2*kco2*pco2x/prox+k1naso4*so4f)**2d0 &
        & *(k1naco3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0+k1nahco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0)
    dnaf_dso4f = nax*(-1d0)/(1d0+k1naco3*k1*k2*kco2*pco2x/prox**2d0+k1nahco3*k1*k2*kco2*pco2x/prox+k1naso4*so4f)**2d0 &
        & *(k1naso4)
        
    caf = cax/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox+k1caso4*so4f)
    dcaf_dpro = cax*(-1d0)/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox+k1caso4*so4f)**2d0 &
        & *(k1ca*(-1d0)/prox**2d0+k1caco3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0+k1cahco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0)
    dcaf_dso4f = cax*(-1d0)/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox+k1caso4*so4f)**2d0 &
        & *(k1caso4)
        
    mgf = mgx/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox+k1mgso4*so4f)
    dmgf_dpro = mgx*(-1d0)/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox+k1mgso4*so4f)**2d0 &
        & *(k1mg*(-1d0)/prox**2d0+k1mgco3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0+k1mghco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0)
    dmgf_dso4f = mgx*(-1d0)/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox+k1mgso4*so4f)**2d0 &
        & *(k1mgso4)
        
    fe2f = fe2x/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox+k1fe2so4*so4f)
    dfe2f_dpro = fe2x*(-1d0) &
        & /(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox+k1fe2so4*so4f)**2d0 &
        & *(k1fe2*(-1d0)/prox**2d0+k1fe2co3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0+k1fe2hco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0)
    dfe2f_dso4f = fe2x*(-1d0) &
        & /(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox+k1fe2so4*so4f)**2d0 &
        & *(k1fe2so4)
        
    sif = six/(1d0+k1si/prox+k2si/prox**2d0)
    ! dsif_dpro = six*(-1d0)/(k1si*(-1d0)/prox**2d0+k2si*(-2d0)/prox**3d0)
    dsif_dpro = six*(-1d0)/(1d0+k1si/prox+k2si/prox**2d0)**2d0*(k1si*(-1d0)/prox**2d0+k2si*(-2d0)/prox**3d0)
    dsif_dso4f = 0d0
    
    alf = alx/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0+k1also4*so4f)
    dalf_dpro = alx*(-1d0)/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0+k1also4*so4f)**2d0 &
        & *(k1al*(-1d0)/prox**2d0+k2al*(-2d0)/prox**3d0+k3al*(-3d0)/prox**4d0+k4al*(-4d0)/prox**5d0)
    dalf_dso4f = alx*(-1d0)/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0+k1also4*so4f)**2d0 &
        & *(k1also4)
    
    fe3f = fe3x/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0+k1fe3so4*so4f)
    dfe3f_dpro = fe3x*(-1d0)/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0+k1fe3so4*so4f)**2d0 &
        & *(k1fe3*(-1d0)/prox**2d0+k2fe3*(-2d0)/prox**3d0+k3fe3*(-3d0)/prox**4d0+k4fe3*(-4d0)/prox**5d0)
    dfe3f_dso4f = fe3x*(-1d0)/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0+k1fe3so4*so4f)**2d0 &
        & *(k1fe3so4)
        
    no3f = no3x/(1d0 + k1no3*prox)
    dno3f_dpro = no3x*(-1d0)/(1d0 + k1no3*prox)**2d0 * k1no3
    dno3f_dso4f = 0d0
    
    
#ifdef debug
    call get_maqf_all( &
        & nz,nsp_aq_all,nsp_gas_all &
        & ,chraq_all,chrgas_all &
        & ,keqgas_h,keqaq_h,keqaq_c,keqaq_s,keqaq_no3 &
        & ,mgasx_loc,maqx_loc,prox,so4f &
        & ,dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2 &! output
        & ,maqf_loc  &! output
        & )
    diff_max = 0d0
    diff_max = max(diff_max,maxval(abs(naf - maqf_loc(findloc(chraq_all,'na',dim=1),:))))
    diff_max = max(diff_max,maxval(abs(kf - maqf_loc(findloc(chraq_all,'k',dim=1),:))))
    diff_max = max(diff_max,maxval(abs(so4f - maqf_loc(findloc(chraq_all,'so4',dim=1),:))))
    diff_max = max(diff_max,maxval(abs(no3f - maqf_loc(findloc(chraq_all,'no3',dim=1),:))))
    diff_max = max(diff_max,maxval(abs(sif - maqf_loc(findloc(chraq_all,'si',dim=1),:))))
    diff_max = max(diff_max,maxval(abs(caf - maqf_loc(findloc(chraq_all,'ca',dim=1),:))))
    diff_max = max(diff_max,maxval(abs(mgf - maqf_loc(findloc(chraq_all,'mg',dim=1),:))))
    diff_max = max(diff_max,maxval(abs(fe2f - maqf_loc(findloc(chraq_all,'fe2',dim=1),:))))
    diff_max = max(diff_max,maxval(abs(alf - maqf_loc(findloc(chraq_all,'al',dim=1),:))))
    diff_max = max(diff_max,maxval(abs(fe3f - maqf_loc(findloc(chraq_all,'fe3',dim=1),:))))
    
    if (diff_max > 0d0) then 
        print *
        print * , 'na',maxval(abs(naf - maqf_loc(findloc(chraq_all,'na',dim=1),:)))
        print * , 'k',maxval(abs(kf - maqf_loc(findloc(chraq_all,'k',dim=1),:)))
        print * , 'so4',maxval(abs(so4f - maqf_loc(findloc(chraq_all,'so4',dim=1),:)))
        print * , 'no3',maxval(abs(no3f - maqf_loc(findloc(chraq_all,'no3',dim=1),:)))
        print * , 'si',maxval(abs(sif - maqf_loc(findloc(chraq_all,'si',dim=1),:)))
        print * , 'ca',maxval(abs(caf - maqf_loc(findloc(chraq_all,'ca',dim=1),:)))
        print * , 'mg',maxval(abs(mgf - maqf_loc(findloc(chraq_all,'mg',dim=1),:)))
        print * , 'fe2',maxval(abs(fe2f - maqf_loc(findloc(chraq_all,'fe2',dim=1),:)))
        print * , 'al',maxval(abs(alf - maqf_loc(findloc(chraq_all,'al',dim=1),:)))
        print * , 'fe3',maxval(abs(fe3f - maqf_loc(findloc(chraq_all,'fe3',dim=1),:)))
        print *
        ! print * , 'na'
        ! print *, naf 
        ! print *, maqf_loc(findloc(chraq_all,'na',dim=1),:)
        pause
    endif 
    
    diff_max = 0d0
    diff_max = max(diff_max,maxval(abs(dnaf_dpro - dmaqf_dpro(findloc(chraq_all,'na',dim=1),:))))
    diff_max = max(diff_max,maxval(abs(dkf_dpro - dmaqf_dpro(findloc(chraq_all,'k',dim=1),:))))
    diff_max = max(diff_max,maxval(abs( - dmaqf_dpro(findloc(chraq_all,'so4',dim=1),:))))
    diff_max = max(diff_max,maxval(abs(dno3f_dpro - dmaqf_dpro(findloc(chraq_all,'no3',dim=1),:))))
    diff_max = max(diff_max,maxval(abs(dsif_dpro - dmaqf_dpro(findloc(chraq_all,'si',dim=1),:))))
    diff_max = max(diff_max,maxval(abs(dcaf_dpro - dmaqf_dpro(findloc(chraq_all,'ca',dim=1),:))))
    diff_max = max(diff_max,maxval(abs(dmgf_dpro - dmaqf_dpro(findloc(chraq_all,'mg',dim=1),:))))
    diff_max = max(diff_max,maxval(abs(dfe2f_dpro - dmaqf_dpro(findloc(chraq_all,'fe2',dim=1),:))))
    diff_max = max(diff_max,maxval(abs(dalf_dpro - dmaqf_dpro(findloc(chraq_all,'al',dim=1),:))))
    diff_max = max(diff_max,maxval(abs(dfe3f_dpro - dmaqf_dpro(findloc(chraq_all,'fe3',dim=1),:))))
    
    if (diff_max > 0d0) then 
        print *
        print * , 'na',maxval(abs(dnaf_dpro - dmaqf_dpro(findloc(chraq_all,'na',dim=1),:)))
        print * , 'k',maxval(abs(dkf_dpro - dmaqf_dpro(findloc(chraq_all,'k',dim=1),:)))
        print * , 'so4',maxval(abs( - dmaqf_dpro(findloc(chraq_all,'so4',dim=1),:)))
        print * , 'no3',maxval(abs(dno3f_dpro - dmaqf_dpro(findloc(chraq_all,'no3',dim=1),:)))
        print * , 'ca',maxval(abs(dcaf_dpro - dmaqf_dpro(findloc(chraq_all,'ca',dim=1),:)))
        print * , 'si',maxval(abs(dsif_dpro - dmaqf_dpro(findloc(chraq_all,'si',dim=1),:)))
        print * , 'mg',maxval(abs(dmgf_dpro - dmaqf_dpro(findloc(chraq_all,'mg',dim=1),:)))
        print * , 'fe2',maxval(abs(dfe2f_dpro - dmaqf_dpro(findloc(chraq_all,'fe2',dim=1),:)))
        print * , 'al',maxval(abs(dalf_dpro - dmaqf_dpro(findloc(chraq_all,'al',dim=1),:)))
        print * , 'fe3',maxval(abs(dfe3f_dpro - dmaqf_dpro(findloc(chraq_all,'fe3',dim=1),:)))
        print *
        ! print * , 'si'
        ! print *, dsif_dpro 
        ! print *, dmaqf_dpro(findloc(chraq_all,'si',dim=1),:)
        pause
    endif 
#endif 
    
    f1 = prox**3d0 - (k1*kco2*pco2x+kw)*prox - 2d0*k2*k1*kco2*pco2x  - no3f*prox**2d0 + pnh3x*knh3/k1nh3*prox**3d0 &
        ! so4
        & -2d0*so4f*prox**2d0 &
        & -1d0*so4f*prox**3d0*k1so4 &
        ! k
        & + kf*prox**2d0 &
        & - kf*prox**2d0*k1kso4*so4f &
        ! na
        & + naf*prox**2d0 &
        & -1d0*naf*k1naco3*k1*k2*kco2*pco2x  &
        & -1d0*naf*prox**2d0*k1naso4*so4f  &
        ! si 
        & - sif*k1si*prox &
        & - 2d0*sif*k2si &
        ! mg
        & + 2d0*mgf*prox**2d0 &
        & + mgf*k1mg*prox &
        & + mgf*k1mghco3*k1*k2*kco2*pco2x*prox  &
        ! ca
        & + 2d0*caf*prox**2d0 &
        & + caf*k1ca*prox &
        & + caf*k1cahco3*k1*k2*kco2*pco2x*prox &
        ! al
        & + 3d0*alf*prox**2d0 &
        & + 2d0*alf*k1al*prox &
        & + alf*k2al &
        & - alf*k4al/prox**2d0 &
        & + alf*k1also4*so4f*prox**2d0 &
        ! fe2
        & + 2d0*fe2f*prox**2d0 &
        & + fe2f*k1fe2*prox &
        & + fe2f*k1fe2hco3*k1*k2*kco2*pco2x*prox &
        ! fe3
        & + 3d0*fe3f*prox**2d0 &
        & + 2d0*fe3f*k1fe3*prox &
        & + fe3f*k2fe3 &
        & - fe3f*k4fe3/prox**2d0 &
        & + fe3f*k1fe3so4*so4f*prox**2d0 
        
    df1 = 3d0*prox**2d0 - (k1*kco2*pco2x+kw)*1d0 - no3f*prox*2d0 + pnh3x*knh3/k1nh3*3d0*prox**2d0 &
        ! so4
        & -2d0*so4f*prox*2d0 &
        & -1d0*so4f*3d0*prox**2d0*k1so4 &
        ! k
        & + dkf_dpro*prox**2d0 &
        & + kf*prox*2d0 &
        & - dkf_dpro*prox**2d0*k1kso4*so4f &
        & - kf*prox*2d0*k1kso4*so4f &
        ! na
        & + dnaf_dpro*prox**2d0 &
        & + naf*prox*2d0 &
        & -1d0*dnaf_dpro*k1naco3*k1*k2*kco2*pco2x  &
        & -1d0*dnaf_dpro*prox**2d0*k1naso4*so4f  &
        & -1d0*naf*prox*2d0*k1naso4*so4f  &
        ! si 
        & - dsif_dpro*k1si*prox &
        & - sif*k1si &
        & - 2d0*dsif_dpro*k2si &
        ! mg
        & + 2d0*dmgf_dpro*prox**2d0 &
        & + 2d0*mgf*prox*2d0 &
        & + dmgf_dpro*k1mg*prox &
        & + mgf*k1mg &
        & + dmgf_dpro*k1mghco3*k1*k2*kco2*pco2x*prox  &
        & + mgf*k1mghco3*k1*k2*kco2*pco2x  &
        ! ca
        & + 2d0*dcaf_dpro*prox**2d0 &
        & + 2d0*caf*prox*2d0 &
        & + dcaf_dpro*k1ca*prox &
        & + caf*k1ca &
        & + dcaf_dpro*k1cahco3*k1*k2*kco2*pco2x*prox &
        & + caf*k1cahco3*k1*k2*kco2*pco2x &
        ! al
        & + 3d0*dalf_dpro*prox**2d0 &
        & + 3d0*alf*prox*2d0 &
        & + 2d0*dalf_dpro*k1al*prox &
        & + 2d0*alf*k1al &
        & + dalf_dpro*k2al &
        & - dalf_dpro*k4al/prox**2d0 &
        & - alf*k4al*(-2d0)/prox**3d0 &
        & + dalf_dpro*k1also4*so4f*prox**2d0 &
        & + alf*k1also4*so4f*prox*2d0 &
        ! fe2
        & + 2d0*dfe2f_dpro*prox**2d0 &
        & + 2d0*fe2f*prox*2d0 &
        & + dfe2f_dpro*k1fe2*prox &
        & + fe2f*k1fe2 &
        & + dfe2f_dpro*k1fe2hco3*k1*k2*kco2*pco2x*prox &
        & + fe2f*k1fe2hco3*k1*k2*kco2*pco2x &
        ! fe3
        & + 3d0*dfe3f_dpro*prox**2d0 &
        & + 3d0*fe3f*prox*2d0 &
        & + 2d0*dfe3f_dpro*k1fe3*prox &
        & + 2d0*fe3f*k1fe3 &
        & + dfe3f_dpro*k2fe3 &
        & - dfe3f_dpro*k4fe3/prox**2d0 &
        & - fe3f*k4fe3*(-2d0)/prox**3d0 &
        & + dfe3f_dpro*k1fe3so4*so4f*prox**2d0 &
        & + fe3f*k1fe3so4*so4f*prox*2d0 
    
    df12 =   &
        ! so4
        & -2d0*1d0*prox**2d0 &
        & -1d0*1d0*prox**3d0*k1so4 &
        ! k
        & + dkf_dso4f*prox**2d0 &
        & - dkf_dso4f*prox**2d0*k1kso4*so4f &
        & - kf*prox**2d0*k1kso4*1d0 &
        ! na
        & + dnaf_dso4f*prox**2d0 &
        & -1d0*dnaf_dso4f*k1naco3*k1*k2*kco2*pco2x  &
        & -1d0*dnaf_dso4f*prox**2d0*k1naso4*so4f  &
        & -1d0*naf*prox**2d0*k1naso4*1d0  &
        ! si 
        & - dsif_dso4f*k1si*prox &
        & - 2d0*dsif_dso4f*k2si &
        ! mg
        & + 2d0*dmgf_dso4f*prox**2d0 &
        & + dmgf_dso4f*k1mg*prox &
        & + dmgf_dso4f*k1mghco3*k1*k2*kco2*pco2x*prox  &
        ! ca
        & + 2d0*dcaf_dso4f*prox**2d0 &
        & + dcaf_dso4f*k1ca*prox &
        & + dcaf_dso4f*k1cahco3*k1*k2*kco2*pco2x*prox &
        ! al
        & + 3d0*dalf_dso4f*prox**2d0 &
        & + 2d0*dalf_dso4f*k1al*prox &
        & + dalf_dso4f*k2al &
        & - dalf_dso4f*k4al/prox**2d0 &
        & + dalf_dso4f*k1also4*so4f*prox**2d0 &
        & + alf*k1also4*1d0*prox**2d0 &
        ! fe2
        & + 2d0*dfe2f_dso4f*prox**2d0 &
        & + dfe2f_dso4f*k1fe2*prox &
        & + dfe2f_dso4f*k1fe2hco3*k1*k2*kco2*pco2x*prox &
        ! fe3
        & + 3d0*dfe3f_dso4f*prox**2d0 &
        & + 2d0*dfe3f_dso4f*k1fe3*prox &
        & + dfe3f_dso4f*k2fe3 &
        & - dfe3f_dso4f*k4fe3/prox**2d0 &
        & + dfe3f_dso4f*k1fe3so4*so4f*prox**2d0 &
        & + fe3f*k1fe3so4*1d0*prox**2d0 
        
        
#ifdef debug
    call calc_charge( &
        & nz,nsp_aq_all,nsp_gas_all &
        & ,chraq_all,chrgas_all &
        & ,kw,keqgas_h,keqaq_h,keqaq_c,keqaq_s  &
        & ,mgasx_loc,maqf_loc &
        & ,dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2 &
        & ,z,prox,so4f &
        & ,print_loc,print_res,ph_add_order &
        & ,df1_dum,df12_dum,df1dmaq,df1dmgas &!output
        & ,f1_dum &! output
        & )
    diff_max = 0d0
    diff_max = max(diff_max,maxval(abs(f1-f1_dum)))
    diff_max = max(diff_max,maxval(abs((df1-df1_dum)/df1)))
    diff_max = max(diff_max,maxval(abs((df12-df12_dum)/df12)))
    if (diff_max > 1d-10) then 
        print *
        print * , 'f1',maxval(abs(f1-f1_dum))
        print * , 'df1',maxval(abs((df1-df1_dum)/df1))
        print * , 'df12',maxval(abs((df12-df12_dum)/df12))
        print *
        pause
    endif 
#endif 
        
    
    f2 = prox**2d0*so4x - prox**2d0*so4f*( 1d0+k1so4*prox &
        & +k1kso4*kf &
        & +k1naso4*naf &
        & +k1caso4*caf &
        & +k1mgso4*mgf &
        & +k1fe2so4*fe2f &
        & +k1also4*alf &
        & +k1fe3so4*fe3f &
        & )
        
    df2 =  - prox**2d0*1d0*( 1d0+k1so4*prox &
        & +k1kso4*kf &
        & +k1naso4*naf &
        & +k1caso4*caf &
        & +k1mgso4*mgf &
        & +k1fe2so4*fe2f &
        & +k1also4*alf &
        & +k1fe3so4*fe3f &
        & ) &
        & - prox**2d0*so4f*(  &
        & +k1kso4*dkf_dso4f &
        & +k1naso4*dnaf_dso4f &
        & +k1caso4*dcaf_dso4f &
        & +k1mgso4*dmgf_dso4f &
        & +k1fe2so4*dfe2f_dso4f &
        & +k1also4*dalf_dso4f &
        & +k1fe3so4*dfe3f_dso4f &
        & )
        
    df21 = 2d0*prox*so4x- prox**2d0*so4f*( k1so4*1d0 &
        & +k1kso4*dkf_dpro &
        & +k1naso4*dnaf_dpro &
        & +k1caso4*dcaf_dpro &
        & +k1mgso4*dmgf_dpro &
        & +k1fe2so4*dfe2f_dpro &
        & +k1also4*dalf_dpro &
        & +k1fe3so4*dfe3f_dpro &
        & ) &
        & -2d0*prox*so4f*( 1d0+k1so4*prox &
        & +k1kso4*kf &
        & +k1naso4*naf &
        & +k1caso4*caf &
        & +k1mgso4*mgf &
        & +k1fe2so4*fe2f &
        & +k1also4*alf &
        & +k1fe3so4*fe3f &
        & )
        
        
#ifdef debug 
    call calc_so4_balance( &
        & nz,nsp_aq_all,nsp_gas_all &
        & ,chraq_all,chrgas_all &
        & ,keqaq_h,keqaq_s  &
        & ,maqf_loc &
        & ,dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2 &
        & ,prox,so4f,so4x &
        & ,ph_add_order &
        & ,df2_dum,df21_dum,df2dmaq,df2dmgas &! output
        & ,f2_dum &! output
        & )
    diff_max = 0d0
    diff_max = max(diff_max,maxval(abs(f2-f2_dum)))
    diff_max = max(diff_max,maxval(abs(df2-df2_dum)/df2))
    diff_max = max(diff_max,maxval(abs((df21-df21_dum)/df21)))
    if (diff_max > 1d-10) then 
        print *
        print * , 'f2',maxval(abs(f2-f2_dum))
        print * , 'df2',maxval(abs(df2-df2_dum)/df2)
        print * , 'df21',maxval(abs((df21-df21_dum)/df21))
        print *
        print *,df21
        print *,df21_dum
        print *
        print *,'so4x', prox**2d0*so4x 
        print * ,'so4f',- prox**2d0*so4f* 1d0 
        print * ,'mgso4',- prox**2d0*so4f* k1mgso4*mgf 
        print * ,'naso4',- prox**2d0*so4f* k1naso4*naf
        print * ,'caso4',- prox**2d0*so4f* k1caso4*caf   
        print * ,'also4',- prox**2d0*so4f* k1also4*alf 
        print * ,'fe2so4',- prox**2d0*so4f* k1fe2so4*fe2f
        print * ,'fe3so4',- prox**2d0*so4f* k1fe3so4*fe3f 
        print *,'hso4',- prox**2d0*so4f* k1so4*prox 
        print * ,'kso4',- prox**2d0*so4f* k1kso4*kf 
        pause
        
    endif 
#endif 
        
! #ifdef debug 
    ! print *, 'v7_2 '
    ! print * , iter
    ! print *, 'f1',f1
    ! print *
    ! print *, 'df1',df1
    ! print *
    ! print *, 'df12',df12
    ! print *
    ! print *, 'f2',f2
    ! print *
    ! print *, 'df2',df2
    ! print *
    ! print *, 'df21',df21
    ! print *
    ! print *, 'prox',prox
    ! print *
    ! print *, 'so4f',so4f
    ! print *
! #endif 
        
        
    df1 = df1*prox
    df21 = df21*prox
    df2 = df2*so4f
    df12 = df12*so4f
    
    if (any(isnan(f1)).or.any(isnan(f2)).or.any(isnan(df1)).or.any(isnan(df2)) &
        & .or.any(isnan(df12)).or.any(isnan(df21))) then 
        print*,'found nan during the course of ph calc'
        print *,any(isnan(f1)),any(isnan(f2)),any(isnan(df1)),any(isnan(df2)) &
            & ,any(isnan(df12)),any(isnan(df21))
        print *,prox
        ph_error = .true.
        exit
        ! pause 
    endif 
    
    
    if (nmx/=nz) then 
        amx = 0d0
        ymx = 0d0
        
        ymx(1:nz) = f1
        ymx(nz+1:nmx) = f2
        
        do iz=1,nz
            amx(iz,iz)=df1(iz)
            amx(nz+iz,nz+iz)=df2(iz)
            amx(iz,nz+iz)=df12(iz)
            amx(nz+iz,iz)=df21(iz)
        enddo 
        ymx = -ymx
        
        call DGESV(nmx,int(1),amx,nmx,ipiv,ymx,nmx,info) 
        
        prox = prox*exp( ymx(1:nz) )
        so4f = so4f*exp( ymx(nz+1:nmx) )
        
        error = maxval(abs(exp( ymx )-1d0))
        if (isnan(error)) then 
            error = 1d4
            ph_error = .true.
            exit 
        endif 
    else 
        prox = prox*exp( -f1/df1 )
        error = maxval(abs(exp( -f1/df1 )-1d0))
        if (isnan(error)) error = 1d4
    endif 
    
    iter = iter + 1
    
    if (iter > 3000) then 
        print *,'iteration exceeds 3000'
        ph_error = .true.
        return
    endif 
enddo 
#ifdef timing 
call cpu_time( t2 )
print *, "cpu time:", t2-t1, "seconds [v7_2] per ph & SO4f soultion."
#endif 

ph_iter = iter

if (any(isnan(prox)) .or. any(prox<=0d0)) then     
    print *, (-log10(prox(iz)),iz=1,nz,nz/5)
    print*,'ph is nan or <= 0'
    ph_error = .true.
    ! stop
endif 
    
kf = kx/(1d0+k1kso4*so4f)

naf = nax/(1d0+k1naco3*k1*k2*kco2*pco2x/prox**2d0+k1nahco3*k1*k2*kco2*pco2x/prox+k1naso4*so4f)
    
caf = cax/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox+k1caso4*so4f)
    
mgf = mgx/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox+k1mgso4*so4f)
    
fe2f = fe2x/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox+k1fe2so4*so4f)
    
sif = six/(1d0+k1si/prox+k2si/prox**2d0)

alf = alx/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0+k1also4*so4f)

fe3f = fe3x/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0+k1fe3so4*so4f)

no3f = no3x/(1d0 + k1no3*prox)

#ifdef debug
call get_maqf_all( &
    & nz,nsp_aq_all,nsp_gas_all &
    & ,chraq_all,chrgas_all &
    & ,keqgas_h,keqaq_h,keqaq_c,keqaq_s,keqaq_no3 &
    & ,mgasx_loc,maqx_loc,prox,so4f &
    & ,dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2 &! output
    & ,maqf_loc  &! output
    & )
    
! print *
! print*,'k',maxval(abs(kf-maqf_loc(findloc(chraq_all,'k',dim=1),:)))
! print*,'na',maxval(abs(naf-maqf_loc(findloc(chraq_all,'na',dim=1),:)))
! print*,'ca',maxval(abs(caf-maqf_loc(findloc(chraq_all,'ca',dim=1),:)))
! print*,'mg',maxval(abs(mgf-maqf_loc(findloc(chraq_all,'mg',dim=1),:)))
! print*,'fe2',maxval(abs(fe2f-maqf_loc(findloc(chraq_all,'fe2',dim=1),:)))
! print*,'si',maxval(abs(sif-maqf_loc(findloc(chraq_all,'si',dim=1),:)))
! print*,'al',maxval(abs(alf-maqf_loc(findloc(chraq_all,'al',dim=1),:)))
! print*,'fe3',maxval(abs(fe3f-maqf_loc(findloc(chraq_all,'fe3',dim=1),:)))
! print*,'no3',maxval(abs(no3f-maqf_loc(findloc(chraq_all,'no3',dim=1),:)))
! print *
#endif 
       
if (print_cb) then 
    open(88,file = trim(adjustl(print_loc)),status='replace')
    write(88,*) ' z ',' h+ ',' oh- ' &
        & ,' no3- ', ' hno3 ' &
        & ,' nh4+ ',' na+ ',' naco3- ', ' nahco3 ', ' naso4- ', ' k+ ',' kso4- ' &
        & ,' so42- ', ' hso4- ', 'hco3- ', ' co32- ' &
        & ,' h4sio4 ',' h3sio4- ',' h2sio42- ' &
        & ,' mg2+ ', ' mg(oh)+ ', ' mgco3 ', 'mghco3+ ', 'mgso4 ' &
        & , ' ca2+ ', ' ca(oh)+ ', ' caco3 ', ' cahco3+ ', ' caso4 ' &
        & ,' al3+ ', ' al(oh)2+ ', ' al(oh)2+ ', ' al(oh)3 ', ' al(oh)4- ' , ' also4+ ' &
        & , ' fe22+ ', ' fe2(oh)+ ', ' fe2co3 ', ' fe2hco3+ ', ' fe2so4 ' &
        & ,' fe3+ ', ' fe3(oh)2+ ', ' fe3(oh)2+ ', ' fe3(oh)3 ', ' fe3(oh)4- ', ' fe3so4+ ' &
        & , ' total_charge ' 
    do iz=1,nz
        write(88,*) z(iz) &
        & ,prox(iz) &
        & ,kw/prox(iz) &
        & ,no3f(iz) &
        & ,no3f(iz)*k1no3*prox(iz) &
        & ,pnh3x(iz)*knh3/k1nh3*prox(iz) &
        & ,naf(iz) &
        & ,naf(iz)*k1naco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0 &
        & ,naf(iz)*k1nahco3*k1*k2*kco2*pco2x(iz)/prox(iz)     &
        & ,naf(iz)*k1naso4*so4f(iz)     &
        & ,kf(iz) &
        & ,kf(iz)*k1kso4*so4f(iz) &
        & ,so4f(iz) &
        & ,so4f(iz)*k1so4*prox(iz) &
        & ,k1*kco2*pco2x(iz)/prox(iz) &
        & ,k2*k1*kco2*pco2x(iz)/prox(iz)**2d0 &
        & ,sif(iz) &
        & ,sif(iz)*k1si/prox(iz) &
        & ,sif(iz)*k2si/prox(iz)**2d0 &
        & ,mgf(iz) &
        & ,mgf(iz)*k1mg/prox(iz)  &
        & ,mgf(iz)*k1mgco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0  &
        & ,mgf(iz)*k1mghco3*k1*k2*kco2*pco2x(iz)/prox(iz)  &
        & ,mgf(iz)*k1mgso4*so4f(iz)  &
        & ,caf(iz) &
        & ,caf(iz)*k1ca/prox(iz) &
        & ,caf(iz)*k1caco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0 &
        & ,caf(iz)*k1cahco3*k1*k2*kco2*pco2x(iz)/prox(iz) &
        & ,caf(iz)*k1caso4*so4f(iz) &
        & ,alf(iz) &
        & ,alf(iz)*k1al/prox(iz) &
        & ,alf(iz)*k2al/prox(iz)**2d0 &
        & ,alf(iz)*k3al/prox(iz)**3d0 &
        & ,alf(iz)*k4al/prox(iz)**4d0 &
        & ,alf(iz)*k1also4*so4f(iz) &
        & ,fe2f(iz) &
        & ,fe2f(iz)*k1fe2/prox(iz) &
        & ,fe2f(iz)*k1fe2co3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0 &
        & ,fe2f(iz)*k1fe2hco3*k1*k2*kco2*pco2x(iz)/prox(iz) &
        & ,fe2f(iz)*k1fe2so4*so4f(iz) &
        & ,fe3f(iz) &
        & ,fe3f(iz)*k1fe3/prox(iz) &
        & ,fe3f(iz)*k2fe3/prox(iz)**2d0 &
        & ,fe3f(iz)*k3fe3/prox(iz)**3d0 &
        & ,fe3f(iz)*k4fe3/prox(iz)**4d0 &
        & ,fe3f(iz)*k1fe3so4*so4f(iz) &
        ! charge balance 
        & ,1d0*prox(iz) &
        & +(-1d0)*kw/prox(iz) &
        & +(-1d0)*no3f(iz) &
        & +(0d0)*no3f(iz)*k1no3*prox(iz) &
        & +(1d0)*pnh3x(iz)*knh3/k1nh3*prox(iz) &
        & +(1d0)*naf(iz) &
        & +(-1d0)*naf(iz)*k1naco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0 &
        & +(0d0)*naf(iz)*k1nahco3*k1*k2*kco2*pco2x(iz)/prox(iz)      &
        & +(-1d0)*naf(iz)*k1naso4*so4f(iz)     &
        & +(1d0)*kf(iz) &
        & +(-1d0)*kf(iz)*k1kso4*so4f(iz) &
        & +(-2d0)*so4f(iz) &
        & +(-1d0)*so4f(iz)*k1so4*prox(iz) &
        & +(-1d0)*k1*kco2*pco2x(iz)/prox(iz) &
        & +(-2d0)*k2*k1*kco2*pco2x(iz)/prox(iz)**2d0 &
        & +(0d0)*sif(iz) &
        & +(-1d0)*sif(iz)*k1si/prox(iz) &
        & +(-2d0)*sif(iz)*k2si/prox(iz)**2d0 &
        & +(2d0)*mgf(iz) &
        & +(1d0)*mgf(iz)*k1mg/prox(iz)  &
        & +(0d0)*mgf(iz)*k1mgco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0  &
        & +(1d0)*mgf(iz)*k1mghco3*k1*k2*kco2*pco2x(iz)/prox(iz)  &
        & +(0d0)*mgf(iz)*k1mgso4*so4f(iz)  &
        & +(2d0)*caf(iz) &
        & +(1d0)*caf(iz)*k1ca/prox(iz) &
        & +(0d0)*caf(iz)*k1caco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0 &
        & +(1d0)*caf(iz)*k1cahco3*k1*k2*kco2*pco2x(iz)/prox(iz) &
        & +(0d0)*caf(iz)*k1caso4*so4f(iz) &
        & +(3d0)*alf(iz) &
        & +(2d0)*alf(iz)*k1al/prox(iz) &
        & +(1d0)*alf(iz)*k2al/prox(iz)**2d0 &
        & +(0d0)*alf(iz)*k3al/prox(iz)**3d0 &
        & +(-1d0)*alf(iz)*k4al/prox(iz)**4d0 &
        & +(1d0)*alf(iz)*k1also4*so4f(iz) &
        & +(2d0)*fe2f(iz) &
        & +(1d0)*fe2f(iz)*k1fe2/prox(iz) &
        & +(0d0)*fe2f(iz)*k1fe2co3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0 &
        & +(1d0)*fe2f(iz)*k1fe2hco3*k1*k2*kco2*pco2x(iz)/prox(iz) &
        & +(0d0)*fe2f(iz)*k1fe2so4*so4f(iz) &
        & +(3d0)*fe3f(iz) &
        & +(2d0)*fe3f(iz)*k1fe3/prox(iz) &
        & +(1d0)*fe3f(iz)*k2fe3/prox(iz)**2d0 &
        & +(0d0)*fe3f(iz)*k3fe3/prox(iz)**3d0 &
        & +(-1d0)*fe3f(iz)*k4fe3/prox(iz)**4d0 &
        & +(1d0)*fe3f(iz)*k1fe3so4*so4f(iz) 
    enddo 
    close(88)
endif 
            

endsubroutine calc_pH_v7_2

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine calc_pH_v7_2_dev( &
    & nz,kw,nsp_aq,nsp_gas,nsp_aq_all,nsp_gas_all,nsp_aq_cnst,nsp_gas_cnst &! input 
    & ,chraq,chraq_cnst,chraq_all,chrgas,chrgas_cnst,chrgas_all &!input
    & ,maqx,maqc,mgasx,mgasc,keqgas_h,keqaq_h,keqaq_c,keqaq_s,maqth_all,keqaq_no3,keqaq_nh3 &! input
    & ,print_cb,print_loc,z &! input 
    & ,prox,ph_error,so4f,ph_iter &! output
    & ) 
! solving charge balance:
! [H+] + ZX[Xz+] - ZY[YZ-] - [HCO3-] - 2[CO32-] - [OH-] - [H3SiO4-] - 2[H2SiO42-] = 0
! [H+] + ZX[Xz+] - ZY[YZ-] - k1kco2pCO2/[H+] - 2k2k1kco2pCO2/[H+]^2 - kw/[H+] - [Si]/([H+]/k1si + 1 + k2si/k1si/[H+])
!       - 2[Si]/([H+]^2/k2si + [H+]k1si/k2si + 1) = 0
! [H+]^3 + (ZX[Xz+] - ZY[YZ-])[H+]^2 - (k1kco2pCO2+kw)[H+] - 2k2k1kco2pCO2  = 0
! NetCat is defined as (ZX[Xz+] - ZY[YZ-])
! [H+]^3 + NetCat[H+]^2 - (k1kco2pCO2+kw)[H+] - 2k2k1kco2pCO2  = 0
implicit none
integer,intent(in)::nz
real(kind=8),intent(in)::kw
real(kind=8) kco2,k1,k2,k1si,k2si,k1mg,k1mgco3,k1mghco3,k1ca,k1caco3,k1cahco3,k1al,k2al,k3al,k4al &
    & ,k1fe2,k1fe2co3,k1fe2hco3,k1fe3,k2fe3,k3fe3,k4fe3,k1naco3,k1nahco3,k1so4,k1kso4,k1naso4  &
    & ,k1caso4,k1mgso4,k1fe2so4,k1also4,k1also42,k1fe3so4,k1fe3so42,so4th,knh3,k1nh3,k1no3
real(kind=8),dimension(nz)::nax,mgx,cax,so4x,pco2x,six,alx,fe2x,fe3x,kx,no3x,pnh3x
real(kind=8),dimension(nz)::naf,kf,mgf,caf,fe2f,fe3f,alf,sif,no3f
real(kind=8),dimension(nz)::dnaf_dpro,dkf_dpro,dmgf_dpro,dcaf_dpro,dfe2f_dpro,dfe3f_dpro,dalf_dpro,dsif_dpro,dno3f_dpro
real(kind=8),dimension(nz)::dnaf_dso4f,dkf_dso4f,dmgf_dso4f,dcaf_dso4f,dfe2f_dso4f,dfe3f_dso4f,dalf_dso4f,dsif_dso4f &
    & ,dno3f_dso4f
real(kind=8),dimension(nz),intent(in)::z
real(kind=8),dimension(nz),intent(inout)::prox,so4f
logical,intent(out)::ph_error

real(kind=8),dimension(nz)::df1,f1,f2,df2,df21,df12
real(kind=8) error,tol,dconc
integer iter,iz

integer,intent(in)::nsp_aq,nsp_gas,nsp_aq_all,nsp_gas_all,nsp_aq_cnst,nsp_gas_cnst
character(5),dimension(nsp_aq),intent(in)::chraq
character(5),dimension(nsp_aq_cnst),intent(in)::chraq_cnst
character(5),dimension(nsp_aq_all),intent(in)::chraq_all
character(5),dimension(nsp_gas),intent(in)::chrgas
character(5),dimension(nsp_gas_cnst),intent(in)::chrgas_cnst
character(5),dimension(nsp_gas_all),intent(in)::chrgas_all
real(kind=8),dimension(nsp_aq,nz),intent(in)::maqx
real(kind=8),dimension(nsp_aq_cnst,nz),intent(in)::maqc
real(kind=8),dimension(nsp_gas,nz),intent(in)::mgasx
real(kind=8),dimension(nsp_gas_cnst,nz),intent(in)::mgasc
real(kind=8),dimension(nsp_gas_all,3),intent(in)::keqgas_h
real(kind=8),dimension(nsp_aq_all,4),intent(in)::keqaq_h
real(kind=8),dimension(nsp_aq_all,2),intent(in)::keqaq_c
real(kind=8),dimension(nsp_aq_all,2),intent(in)::keqaq_s
real(kind=8),dimension(nsp_aq_all,2),intent(in)::keqaq_nh3
real(kind=8),dimension(nsp_aq_all,2),intent(in)::keqaq_no3
real(kind=8),dimension(nsp_aq_all),intent(in)::maqth_all

integer,intent(out)::ph_iter

real(kind=8),dimension(nsp_aq_all,nz)::maqx_loc,maqf_loc
real(kind=8),dimension(nsp_aq_all,nz)::dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2
real(kind=8),dimension(nsp_gas_all,nz)::mgasx_loc
real(kind=8),dimension(nsp_aq_all,nz)::df1dmaq,df2dmaq
real(kind=8),dimension(nsp_gas_all,nz)::df1dmgas,df2dmgas

real(kind=8),dimension(nz)::f1_dum,f2_dum,df1_dum,df2_dum,df12_dum,df21_dum

real(kind=8),dimension(nz)::dprodk,dprodpco2

real(kind=8)::ph_add_order = 2d0
logical print_res 
real(kind=8) diff_max

integer ieqgas_h0,ieqgas_h1,ieqgas_h2
data ieqgas_h0,ieqgas_h1,ieqgas_h2/1,2,3/

integer ieqaq_h1,ieqaq_h2,ieqaq_h3,ieqaq_h4
data ieqaq_h1,ieqaq_h2,ieqaq_h3,ieqaq_h4/1,2,3,4/

integer ieqaq_co3,ieqaq_hco3
data ieqaq_co3,ieqaq_hco3/1,2/

integer ieqaq_so4,ieqaq_so42
data ieqaq_so4,ieqaq_so42/1,2/

integer ieqaq_no3,ieqaq_no32
data ieqaq_no3,ieqaq_no32/1,2/

logical,intent(in)::print_cb
character(500),intent(in)::print_loc
logical so4_error

real(kind=8),allocatable::amx(:,:),ymx(:)
integer,allocatable::ipiv(:)
integer info,nmx

! external DGESV
#ifdef timing
real(kind=8) :: t1, t2
#endif 

print_res = print_cb

error = 1d4
tol = 1d-6
dconc = 1d-14

prox = 1d0 
iter = 0


kco2 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h0)
k1 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h1)
k2 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h2)
k1si = keqaq_h(findloc(chraq_all,'si',dim=1),ieqaq_h1)
k2si = keqaq_h(findloc(chraq_all,'si',dim=1),ieqaq_h2)
k1mg = keqaq_h(findloc(chraq_all,'mg',dim=1),ieqaq_h1)
k1mgco3 = keqaq_c(findloc(chraq_all,'mg',dim=1),ieqaq_co3)
k1mghco3  = keqaq_c(findloc(chraq_all,'mg',dim=1),ieqaq_hco3)
k1ca = keqaq_h(findloc(chraq_all,'ca',dim=1),ieqaq_h1)
k1caco3 = keqaq_c(findloc(chraq_all,'ca',dim=1),ieqaq_co3)
k1cahco3 = keqaq_c(findloc(chraq_all,'ca',dim=1),ieqaq_hco3)
k1al= keqaq_h(findloc(chraq_all,'al',dim=1),ieqaq_h1)
k2al= keqaq_h(findloc(chraq_all,'al',dim=1),ieqaq_h2)
k3al= keqaq_h(findloc(chraq_all,'al',dim=1),ieqaq_h3)
k4al= keqaq_h(findloc(chraq_all,'al',dim=1),ieqaq_h4)
k1fe2 = keqaq_h(findloc(chraq_all,'fe2',dim=1),ieqaq_h1)
k1fe2co3 = keqaq_c(findloc(chraq_all,'fe2',dim=1),ieqaq_co3)
k1fe2hco3  = keqaq_c(findloc(chraq_all,'fe2',dim=1),ieqaq_hco3)
k1fe3= keqaq_h(findloc(chraq_all,'fe3',dim=1),ieqaq_h1)
k2fe3= keqaq_h(findloc(chraq_all,'fe3',dim=1),ieqaq_h2)
k3fe3= keqaq_h(findloc(chraq_all,'fe3',dim=1),ieqaq_h3)
k4fe3= keqaq_h(findloc(chraq_all,'fe3',dim=1),ieqaq_h4)
k1naco3 = keqaq_c(findloc(chraq_all,'na',dim=1),ieqaq_co3)
k1nahco3  = keqaq_c(findloc(chraq_all,'na',dim=1),ieqaq_hco3)

k1so4 = keqaq_h(findloc(chraq_all,'so4',dim=1),ieqaq_h1)
k1naso4 = keqaq_s(findloc(chraq_all,'na',dim=1),ieqaq_so4)
k1kso4 = keqaq_s(findloc(chraq_all,'k',dim=1),ieqaq_so4)
k1caso4 = keqaq_s(findloc(chraq_all,'ca',dim=1),ieqaq_so4)
k1mgso4 = keqaq_s(findloc(chraq_all,'mg',dim=1),ieqaq_so4)
k1fe2so4 = keqaq_s(findloc(chraq_all,'fe2',dim=1),ieqaq_so4)
k1also4 = keqaq_s(findloc(chraq_all,'al',dim=1),ieqaq_so4)
k1fe3so4 = keqaq_s(findloc(chraq_all,'fe3',dim=1),ieqaq_so4)
k1also42 = keqaq_s(findloc(chraq_all,'al',dim=1),ieqaq_so42)
k1fe3so42 = keqaq_s(findloc(chraq_all,'fe3',dim=1),ieqaq_so42)

knh3 = keqgas_h(findloc(chrgas_all,'pnh3',dim=1),ieqgas_h0)
k1nh3 = keqgas_h(findloc(chrgas_all,'pnh3',dim=1),ieqgas_h1)

k1no3 = keqaq_h(findloc(chraq_all,'no3',dim=1),ieqaq_h1)

nax = 0d0
so4x = 0d0
kx = 0d0
no3x = 0d0
if (any(chraq=='na')) then 
    nax = maqx(findloc(chraq,'na',dim=1),:)
elseif (any(chraq_cnst=='na')) then 
    nax = maqc(findloc(chraq_cnst,'na',dim=1),:)
endif 
if (any(chraq=='k')) then 
    kx = maqx(findloc(chraq,'k',dim=1),:)
elseif (any(chraq_cnst=='k')) then 
    kx = maqc(findloc(chraq_cnst,'k',dim=1),:)
endif 
if (any(chraq=='so4')) then 
    so4x = maqx(findloc(chraq,'so4',dim=1),:)
elseif (any(chraq_cnst=='so4')) then 
    so4x = maqc(findloc(chraq_cnst,'so4',dim=1),:)
endif 
if (any(chraq=='no3')) then 
    no3x = maqx(findloc(chraq,'no3',dim=1),:)
elseif (any(chraq_cnst=='no3')) then 
    no3x = maqc(findloc(chraq_cnst,'no3',dim=1),:)
endif 


six =0d0
cax =0d0
mgx =0d0
fe2x =0d0
alx =0d0
fe3x =0d0
pco2x =0d0
pnh3x =0d0

if (any(chraq=='si')) then 
    six = maqx(findloc(chraq,'si',dim=1),:)
elseif (any(chraq_cnst=='si')) then 
    six = maqc(findloc(chraq_cnst,'si',dim=1),:)
endif 
if (any(chraq=='ca')) then 
    cax = maqx(findloc(chraq,'ca',dim=1),:)
elseif (any(chraq_cnst=='ca')) then 
    cax = maqc(findloc(chraq_cnst,'ca',dim=1),:)
endif 
if (any(chraq=='mg')) then 
    mgx = maqx(findloc(chraq,'mg',dim=1),:)
elseif (any(chraq_cnst=='mg')) then 
    mgx = maqc(findloc(chraq_cnst,'mg',dim=1),:)
endif 
if (any(chraq=='fe2')) then 
    fe2x = maqx(findloc(chraq,'fe2',dim=1),:)
elseif (any(chraq_cnst=='fe2')) then 
    fe2x = maqc(findloc(chraq_cnst,'fe2',dim=1),:)
endif 
if (any(chraq=='al')) then 
    alx = maqx(findloc(chraq,'al',dim=1),:)
elseif (any(chraq_cnst=='al')) then 
    alx = maqc(findloc(chraq_cnst,'al',dim=1),:)
endif 
if (any(chraq=='fe3')) then 
    fe3x = maqx(findloc(chraq,'fe3',dim=1),:)
elseif (any(chraq_cnst=='fe3')) then 
    fe3x = maqc(findloc(chraq_cnst,'fe3',dim=1),:)
endif 
if (any(chrgas=='pco2')) then 
    pco2x = mgasx(findloc(chrgas,'pco2',dim=1),:)
elseif (any(chrgas_cnst=='pco2')) then 
    pco2x = mgasc(findloc(chrgas_cnst,'pco2',dim=1),:)
endif 
if (any(chrgas=='pnh3')) then 
    pnh3x = mgasx(findloc(chrgas,'pnh3',dim=1),:)
elseif (any(chrgas_cnst=='pnh3')) then 
    pnh3x = mgasc(findloc(chrgas_cnst,'pnh3',dim=1),:)
endif 

if (any(isnan(maqx)) .or. any(isnan(maqc))) then 
    print*,'nan in input aqueosu species'
    stop
endif 

200 continue


#ifdef debug
call get_maqgasx_all( &
    & nz,nsp_aq_all,nsp_gas_all,nsp_aq,nsp_gas,nsp_aq_cnst,nsp_gas_cnst &
    & ,chraq,chraq_all,chraq_cnst,chrgas,chrgas_all,chrgas_cnst &
    & ,maqx,mgasx,maqc,mgasc &
    & ,maqx_loc,mgasx_loc  &! output
    & )
! print *
! print * , 'na',maxval(abs(nax - maqx_loc(findloc(chraq_all,'na',dim=1),:)))
! print * , 'k',maxval(abs(kx - maqx_loc(findloc(chraq_all,'k',dim=1),:)))
! print * , 'so4',maxval(abs(so4x - maqx_loc(findloc(chraq_all,'so4',dim=1),:)))
! print * , 'no3',maxval(abs(no3x - maqx_loc(findloc(chraq_all,'no3',dim=1),:)))
! print * , 'si',maxval(abs(six - maqx_loc(findloc(chraq_all,'si',dim=1),:)))
! print * , 'ca',maxval(abs(cax - maqx_loc(findloc(chraq_all,'ca',dim=1),:)))
! print * , 'mg',maxval(abs(mgx - maqx_loc(findloc(chraq_all,'mg',dim=1),:)))
! print * , 'fe2',maxval(abs(fe2x - maqx_loc(findloc(chraq_all,'fe2',dim=1),:)))
! print * , 'al',maxval(abs(alx - maqx_loc(findloc(chraq_all,'al',dim=1),:)))
! print * , 'fe3',maxval(abs(fe3x - maqx_loc(findloc(chraq_all,'fe3',dim=1),:)))
! print * , 'pco2',maxval(abs(pco2x - mgasx_loc(findloc(chrgas_all,'pco2',dim=1),:)))
! print * , 'pnh3',maxval(abs(pnh3x - mgasx_loc(findloc(chrgas_all,'pnh3',dim=1),:)))
! print *
#endif 

so4th = maqth_all(findloc(chraq_all,'so4',dim=1))

so4f  = so4x 

nmx = 2*nz
! if (all(so4x==0d0)) then 
if (all(so4x<=so4th)) then 
    nmx = nz
#ifdef debug
    print *, 'v7_2 so4f is assumed to be constant'
#endif 
endif  

allocate(amx(nmx,nmx),ymx(nmx),ipiv(nmx))

ph_error = .false.

#ifdef debug
    print *, 'v7_2 nmx = :',nmx
#endif 
! print*,'calc_pH'
#ifdef timing
call cpu_time( t1 )
#endif 
do while (error > tol)
    ! free SO42- (for simplicity only consider XSO4 complex where X is a cation)
    
    kf = kx/(1d0+k1kso4*so4f)
    dkf_dso4f = kx*(-1d0)/(1d0+k1kso4*so4f)**2d0*(k1kso4)
    dkf_dpro = 0d0
    
    naf = nax/(1d0+k1naco3*k1*k2*kco2*pco2x/prox**2d0+k1nahco3*k1*k2*kco2*pco2x/prox+k1naso4*so4f)
    dnaf_dpro = nax*(-1d0)/(1d0+k1naco3*k1*k2*kco2*pco2x/prox**2d0+k1nahco3*k1*k2*kco2*pco2x/prox+k1naso4*so4f)**2d0 &
        & *(k1naco3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0+k1nahco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0)
    dnaf_dso4f = nax*(-1d0)/(1d0+k1naco3*k1*k2*kco2*pco2x/prox**2d0+k1nahco3*k1*k2*kco2*pco2x/prox+k1naso4*so4f)**2d0 &
        & *(k1naso4)
        
    caf = cax/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox+k1caso4*so4f)
    dcaf_dpro = cax*(-1d0)/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox+k1caso4*so4f)**2d0 &
        & *(k1ca*(-1d0)/prox**2d0+k1caco3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0+k1cahco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0)
    dcaf_dso4f = cax*(-1d0)/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox+k1caso4*so4f)**2d0 &
        & *(k1caso4)
        
    mgf = mgx/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox+k1mgso4*so4f)
    dmgf_dpro = mgx*(-1d0)/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox+k1mgso4*so4f)**2d0 &
        & *(k1mg*(-1d0)/prox**2d0+k1mgco3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0+k1mghco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0)
    dmgf_dso4f = mgx*(-1d0)/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox+k1mgso4*so4f)**2d0 &
        & *(k1mgso4)
        
    fe2f = fe2x/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox+k1fe2so4*so4f)
    dfe2f_dpro = fe2x*(-1d0) &
        & /(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox+k1fe2so4*so4f)**2d0 &
        & *(k1fe2*(-1d0)/prox**2d0+k1fe2co3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0+k1fe2hco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0)
    dfe2f_dso4f = fe2x*(-1d0) &
        & /(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox+k1fe2so4*so4f)**2d0 &
        & *(k1fe2so4)
        
    sif = six/(1d0+k1si/prox+k2si/prox**2d0)
    ! dsif_dpro = six*(-1d0)/(k1si*(-1d0)/prox**2d0+k2si*(-2d0)/prox**3d0)
    dsif_dpro = six*(-1d0)/(1d0+k1si/prox+k2si/prox**2d0)**2d0*(k1si*(-1d0)/prox**2d0+k2si*(-2d0)/prox**3d0)
    dsif_dso4f = 0d0
    
    alf = alx/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0+k1also4*so4f)
    dalf_dpro = alx*(-1d0)/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0+k1also4*so4f)**2d0 &
        & *(k1al*(-1d0)/prox**2d0+k2al*(-2d0)/prox**3d0+k3al*(-3d0)/prox**4d0+k4al*(-4d0)/prox**5d0)
    dalf_dso4f = alx*(-1d0)/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0+k1also4*so4f)**2d0 &
        & *(k1also4)
    
    fe3f = fe3x/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0+k1fe3so4*so4f)
    dfe3f_dpro = fe3x*(-1d0)/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0+k1fe3so4*so4f)**2d0 &
        & *(k1fe3*(-1d0)/prox**2d0+k2fe3*(-2d0)/prox**3d0+k3fe3*(-3d0)/prox**4d0+k4fe3*(-4d0)/prox**5d0)
    dfe3f_dso4f = fe3x*(-1d0)/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0+k1fe3so4*so4f)**2d0 &
        & *(k1fe3so4)
        
    no3f = no3x/(1d0 + k1no3*prox)
    dno3f_dpro = no3x*(-1d0)/(1d0 + k1no3*prox)**2d0 * k1no3
    dno3f_dso4f = 0d0
    
    
#ifdef debug
    call get_maqf_all( &
        & nz,nsp_aq_all,nsp_gas_all &
        & ,chraq_all,chrgas_all &
        & ,keqgas_h,keqaq_h,keqaq_c,keqaq_s,keqaq_no3 &
        & ,mgasx_loc,maqx_loc,prox,so4f &
        & ,dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2 &! output
        & ,maqf_loc  &! output
        & )
    diff_max = 0d0
    diff_max = max(diff_max,maxval(abs(naf - maqf_loc(findloc(chraq_all,'na',dim=1),:))))
    diff_max = max(diff_max,maxval(abs(kf - maqf_loc(findloc(chraq_all,'k',dim=1),:))))
    diff_max = max(diff_max,maxval(abs(so4f - maqf_loc(findloc(chraq_all,'so4',dim=1),:))))
    diff_max = max(diff_max,maxval(abs(no3f - maqf_loc(findloc(chraq_all,'no3',dim=1),:))))
    diff_max = max(diff_max,maxval(abs(sif - maqf_loc(findloc(chraq_all,'si',dim=1),:))))
    diff_max = max(diff_max,maxval(abs(caf - maqf_loc(findloc(chraq_all,'ca',dim=1),:))))
    diff_max = max(diff_max,maxval(abs(mgf - maqf_loc(findloc(chraq_all,'mg',dim=1),:))))
    diff_max = max(diff_max,maxval(abs(fe2f - maqf_loc(findloc(chraq_all,'fe2',dim=1),:))))
    diff_max = max(diff_max,maxval(abs(alf - maqf_loc(findloc(chraq_all,'al',dim=1),:))))
    diff_max = max(diff_max,maxval(abs(fe3f - maqf_loc(findloc(chraq_all,'fe3',dim=1),:))))
    
    if (diff_max > 0d0) then 
        print *
        print * , 'na',maxval(abs(naf - maqf_loc(findloc(chraq_all,'na',dim=1),:)))
        print * , 'k',maxval(abs(kf - maqf_loc(findloc(chraq_all,'k',dim=1),:)))
        print * , 'so4',maxval(abs(so4f - maqf_loc(findloc(chraq_all,'so4',dim=1),:)))
        print * , 'no3',maxval(abs(no3f - maqf_loc(findloc(chraq_all,'no3',dim=1),:)))
        print * , 'si',maxval(abs(sif - maqf_loc(findloc(chraq_all,'si',dim=1),:)))
        print * , 'ca',maxval(abs(caf - maqf_loc(findloc(chraq_all,'ca',dim=1),:)))
        print * , 'mg',maxval(abs(mgf - maqf_loc(findloc(chraq_all,'mg',dim=1),:)))
        print * , 'fe2',maxval(abs(fe2f - maqf_loc(findloc(chraq_all,'fe2',dim=1),:)))
        print * , 'al',maxval(abs(alf - maqf_loc(findloc(chraq_all,'al',dim=1),:)))
        print * , 'fe3',maxval(abs(fe3f - maqf_loc(findloc(chraq_all,'fe3',dim=1),:)))
        print *
        ! print * , 'na'
        ! print *, naf 
        ! print *, maqf_loc(findloc(chraq_all,'na',dim=1),:)
        pause
    endif 
    
    diff_max = 0d0
    diff_max = max(diff_max,maxval(abs(dnaf_dpro - dmaqf_dpro(findloc(chraq_all,'na',dim=1),:))))
    diff_max = max(diff_max,maxval(abs(dkf_dpro - dmaqf_dpro(findloc(chraq_all,'k',dim=1),:))))
    diff_max = max(diff_max,maxval(abs( - dmaqf_dpro(findloc(chraq_all,'so4',dim=1),:))))
    diff_max = max(diff_max,maxval(abs(dno3f_dpro - dmaqf_dpro(findloc(chraq_all,'no3',dim=1),:))))
    diff_max = max(diff_max,maxval(abs(dsif_dpro - dmaqf_dpro(findloc(chraq_all,'si',dim=1),:))))
    diff_max = max(diff_max,maxval(abs(dcaf_dpro - dmaqf_dpro(findloc(chraq_all,'ca',dim=1),:))))
    diff_max = max(diff_max,maxval(abs(dmgf_dpro - dmaqf_dpro(findloc(chraq_all,'mg',dim=1),:))))
    diff_max = max(diff_max,maxval(abs(dfe2f_dpro - dmaqf_dpro(findloc(chraq_all,'fe2',dim=1),:))))
    diff_max = max(diff_max,maxval(abs(dalf_dpro - dmaqf_dpro(findloc(chraq_all,'al',dim=1),:))))
    diff_max = max(diff_max,maxval(abs(dfe3f_dpro - dmaqf_dpro(findloc(chraq_all,'fe3',dim=1),:))))
    
    if (diff_max > 0d0) then 
        print *
        print * , 'na',maxval(abs(dnaf_dpro - dmaqf_dpro(findloc(chraq_all,'na',dim=1),:)))
        print * , 'k',maxval(abs(dkf_dpro - dmaqf_dpro(findloc(chraq_all,'k',dim=1),:)))
        print * , 'so4',maxval(abs( - dmaqf_dpro(findloc(chraq_all,'so4',dim=1),:)))
        print * , 'no3',maxval(abs(dno3f_dpro - dmaqf_dpro(findloc(chraq_all,'no3',dim=1),:)))
        print * , 'ca',maxval(abs(dcaf_dpro - dmaqf_dpro(findloc(chraq_all,'ca',dim=1),:)))
        print * , 'si',maxval(abs(dsif_dpro - dmaqf_dpro(findloc(chraq_all,'si',dim=1),:)))
        print * , 'mg',maxval(abs(dmgf_dpro - dmaqf_dpro(findloc(chraq_all,'mg',dim=1),:)))
        print * , 'fe2',maxval(abs(dfe2f_dpro - dmaqf_dpro(findloc(chraq_all,'fe2',dim=1),:)))
        print * , 'al',maxval(abs(dalf_dpro - dmaqf_dpro(findloc(chraq_all,'al',dim=1),:)))
        print * , 'fe3',maxval(abs(dfe3f_dpro - dmaqf_dpro(findloc(chraq_all,'fe3',dim=1),:)))
        print *
        ! print * , 'si'
        ! print *, dsif_dpro 
        ! print *, dmaqf_dpro(findloc(chraq_all,'si',dim=1),:)
        pause
    endif 
#endif 
    
    f1 = prox**3d0 - (k1*kco2*pco2x+kw)*prox - 2d0*k2*k1*kco2*pco2x  - no3f*prox**2d0 + pnh3x*knh3/k1nh3*prox**3d0 &
        ! so4
        & -2d0*so4f*prox**2d0 &
        & -1d0*so4f*prox**3d0*k1so4 &
        ! k
        & + kf*prox**2d0 &
        & - kf*prox**2d0*k1kso4*so4f &
        ! na
        & + naf*prox**2d0 &
        & -1d0*naf*k1naco3*k1*k2*kco2*pco2x  &
        & -1d0*naf*prox**2d0*k1naso4*so4f  &
        ! si 
        & - sif*k1si*prox &
        & - 2d0*sif*k2si &
        ! mg
        & + 2d0*mgf*prox**2d0 &
        & + mgf*k1mg*prox &
        & + mgf*k1mghco3*k1*k2*kco2*pco2x*prox  &
        ! ca
        & + 2d0*caf*prox**2d0 &
        & + caf*k1ca*prox &
        & + caf*k1cahco3*k1*k2*kco2*pco2x*prox &
        ! al
        & + 3d0*alf*prox**2d0 &
        & + 2d0*alf*k1al*prox &
        & + alf*k2al &
        & - alf*k4al/prox**2d0 &
        & + alf*k1also4*so4f*prox**2d0 &
        ! fe2
        & + 2d0*fe2f*prox**2d0 &
        & + fe2f*k1fe2*prox &
        & + fe2f*k1fe2hco3*k1*k2*kco2*pco2x*prox &
        ! fe3
        & + 3d0*fe3f*prox**2d0 &
        & + 2d0*fe3f*k1fe3*prox &
        & + fe3f*k2fe3 &
        & - fe3f*k4fe3/prox**2d0 &
        & + fe3f*k1fe3so4*so4f*prox**2d0 
        
    df1 = 3d0*prox**2d0 - (k1*kco2*pco2x+kw)*1d0 - no3f*prox*2d0 + pnh3x*knh3/k1nh3*3d0*prox**2d0 &
        ! so4
        & -2d0*so4f*prox*2d0 &
        & -1d0*so4f*3d0*prox**2d0*k1so4 &
        ! k
        & + dkf_dpro*prox**2d0 &
        & + kf*prox*2d0 &
        & - dkf_dpro*prox**2d0*k1kso4*so4f &
        & - kf*prox*2d0*k1kso4*so4f &
        ! na
        & + dnaf_dpro*prox**2d0 &
        & + naf*prox*2d0 &
        & -1d0*dnaf_dpro*k1naco3*k1*k2*kco2*pco2x  &
        & -1d0*dnaf_dpro*prox**2d0*k1naso4*so4f  &
        & -1d0*naf*prox*2d0*k1naso4*so4f  &
        ! si 
        & - dsif_dpro*k1si*prox &
        & - sif*k1si &
        & - 2d0*dsif_dpro*k2si &
        ! mg
        & + 2d0*dmgf_dpro*prox**2d0 &
        & + 2d0*mgf*prox*2d0 &
        & + dmgf_dpro*k1mg*prox &
        & + mgf*k1mg &
        & + dmgf_dpro*k1mghco3*k1*k2*kco2*pco2x*prox  &
        & + mgf*k1mghco3*k1*k2*kco2*pco2x  &
        ! ca
        & + 2d0*dcaf_dpro*prox**2d0 &
        & + 2d0*caf*prox*2d0 &
        & + dcaf_dpro*k1ca*prox &
        & + caf*k1ca &
        & + dcaf_dpro*k1cahco3*k1*k2*kco2*pco2x*prox &
        & + caf*k1cahco3*k1*k2*kco2*pco2x &
        ! al
        & + 3d0*dalf_dpro*prox**2d0 &
        & + 3d0*alf*prox*2d0 &
        & + 2d0*dalf_dpro*k1al*prox &
        & + 2d0*alf*k1al &
        & + dalf_dpro*k2al &
        & - dalf_dpro*k4al/prox**2d0 &
        & - alf*k4al*(-2d0)/prox**3d0 &
        & + dalf_dpro*k1also4*so4f*prox**2d0 &
        & + alf*k1also4*so4f*prox*2d0 &
        ! fe2
        & + 2d0*dfe2f_dpro*prox**2d0 &
        & + 2d0*fe2f*prox*2d0 &
        & + dfe2f_dpro*k1fe2*prox &
        & + fe2f*k1fe2 &
        & + dfe2f_dpro*k1fe2hco3*k1*k2*kco2*pco2x*prox &
        & + fe2f*k1fe2hco3*k1*k2*kco2*pco2x &
        ! fe3
        & + 3d0*dfe3f_dpro*prox**2d0 &
        & + 3d0*fe3f*prox*2d0 &
        & + 2d0*dfe3f_dpro*k1fe3*prox &
        & + 2d0*fe3f*k1fe3 &
        & + dfe3f_dpro*k2fe3 &
        & - dfe3f_dpro*k4fe3/prox**2d0 &
        & - fe3f*k4fe3*(-2d0)/prox**3d0 &
        & + dfe3f_dpro*k1fe3so4*so4f*prox**2d0 &
        & + fe3f*k1fe3so4*so4f*prox*2d0 
    
    df12 =   &
        ! so4
        & -2d0*1d0*prox**2d0 &
        & -1d0*1d0*prox**3d0*k1so4 &
        ! k
        & + dkf_dso4f*prox**2d0 &
        & - dkf_dso4f*prox**2d0*k1kso4*so4f &
        & - kf*prox**2d0*k1kso4*1d0 &
        ! na
        & + dnaf_dso4f*prox**2d0 &
        & -1d0*dnaf_dso4f*k1naco3*k1*k2*kco2*pco2x  &
        & -1d0*dnaf_dso4f*prox**2d0*k1naso4*so4f  &
        & -1d0*naf*prox**2d0*k1naso4*1d0  &
        ! si 
        & - dsif_dso4f*k1si*prox &
        & - 2d0*dsif_dso4f*k2si &
        ! mg
        & + 2d0*dmgf_dso4f*prox**2d0 &
        & + dmgf_dso4f*k1mg*prox &
        & + dmgf_dso4f*k1mghco3*k1*k2*kco2*pco2x*prox  &
        ! ca
        & + 2d0*dcaf_dso4f*prox**2d0 &
        & + dcaf_dso4f*k1ca*prox &
        & + dcaf_dso4f*k1cahco3*k1*k2*kco2*pco2x*prox &
        ! al
        & + 3d0*dalf_dso4f*prox**2d0 &
        & + 2d0*dalf_dso4f*k1al*prox &
        & + dalf_dso4f*k2al &
        & - dalf_dso4f*k4al/prox**2d0 &
        & + dalf_dso4f*k1also4*so4f*prox**2d0 &
        & + alf*k1also4*1d0*prox**2d0 &
        ! fe2
        & + 2d0*dfe2f_dso4f*prox**2d0 &
        & + dfe2f_dso4f*k1fe2*prox &
        & + dfe2f_dso4f*k1fe2hco3*k1*k2*kco2*pco2x*prox &
        ! fe3
        & + 3d0*dfe3f_dso4f*prox**2d0 &
        & + 2d0*dfe3f_dso4f*k1fe3*prox &
        & + dfe3f_dso4f*k2fe3 &
        & - dfe3f_dso4f*k4fe3/prox**2d0 &
        & + dfe3f_dso4f*k1fe3so4*so4f*prox**2d0 &
        & + fe3f*k1fe3so4*1d0*prox**2d0 
        
        
#ifdef debug
    call calc_charge( &
        & nz,nsp_aq_all,nsp_gas_all &
        & ,chraq_all,chrgas_all &
        & ,kw,keqgas_h,keqaq_h,keqaq_c,keqaq_s  &
        & ,mgasx_loc,maqf_loc &
        & ,dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2 &
        & ,z,prox,so4f &
        & ,print_loc,print_res,ph_add_order &
        & ,df1_dum,df12_dum,df1dmaq,df1dmgas &!output
        & ,f1_dum &! output
        & )
    diff_max = 0d0
    diff_max = max(diff_max,maxval(abs(f1-f1_dum)))
    diff_max = max(diff_max,maxval(abs((df1-df1_dum)/df1)))
    diff_max = max(diff_max,maxval(abs((df12-df12_dum)/df12)))
    if (diff_max > 1d-10) then 
        print *
        print * , 'f1',maxval(abs(f1-f1_dum))
        print * , 'df1',maxval(abs((df1-df1_dum)/df1))
        print * , 'df12',maxval(abs((df12-df12_dum)/df12))
        print *
        pause
    endif 
#endif 
        
    
    f2 = prox**2d0*so4x - prox**2d0*so4f*( 1d0+k1so4*prox &
        & +k1kso4*kf &
        & +k1naso4*naf &
        & +k1caso4*caf &
        & +k1mgso4*mgf &
        & +k1fe2so4*fe2f &
        & +k1also4*alf &
        & +k1fe3so4*fe3f &
        & )
        
    df2 =  - prox**2d0*1d0*( 1d0+k1so4*prox &
        & +k1kso4*kf &
        & +k1naso4*naf &
        & +k1caso4*caf &
        & +k1mgso4*mgf &
        & +k1fe2so4*fe2f &
        & +k1also4*alf &
        & +k1fe3so4*fe3f &
        & ) &
        & - prox**2d0*so4f*(  &
        & +k1kso4*dkf_dso4f &
        & +k1naso4*dnaf_dso4f &
        & +k1caso4*dcaf_dso4f &
        & +k1mgso4*dmgf_dso4f &
        & +k1fe2so4*dfe2f_dso4f &
        & +k1also4*dalf_dso4f &
        & +k1fe3so4*dfe3f_dso4f &
        & )
        
    df21 = 2d0*prox*so4x- prox**2d0*so4f*( k1so4*1d0 &
        & +k1kso4*dkf_dpro &
        & +k1naso4*dnaf_dpro &
        & +k1caso4*dcaf_dpro &
        & +k1mgso4*dmgf_dpro &
        & +k1fe2so4*dfe2f_dpro &
        & +k1also4*dalf_dpro &
        & +k1fe3so4*dfe3f_dpro &
        & ) &
        & -2d0*prox*so4f*( 1d0+k1so4*prox &
        & +k1kso4*kf &
        & +k1naso4*naf &
        & +k1caso4*caf &
        & +k1mgso4*mgf &
        & +k1fe2so4*fe2f &
        & +k1also4*alf &
        & +k1fe3so4*fe3f &
        & )
        
        
#ifdef debug 
    call calc_so4_balance( &
        & nz,nsp_aq_all,nsp_gas_all &
        & ,chraq_all,chrgas_all &
        & ,keqaq_h,keqaq_s  &
        & ,maqf_loc &
        & ,dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2 &
        & ,prox,so4f,so4x &
        & ,ph_add_order &
        & ,df2_dum,df21_dum,df2dmaq,df2dmgas &! output
        & ,f2_dum &! output
        & )
    diff_max = 0d0
    diff_max = max(diff_max,maxval(abs(f2-f2_dum)))
    diff_max = max(diff_max,maxval(abs(df2-df2_dum)/df2))
    diff_max = max(diff_max,maxval(abs((df21-df21_dum)/df21)))
    if (diff_max > 1d-10) then 
        print *
        print * , 'f2',maxval(abs(f2-f2_dum))
        print * , 'df2',maxval(abs(df2-df2_dum)/df2)
        print * , 'df21',maxval(abs((df21-df21_dum)/df21))
        print *
        print *,df21
        print *,df21_dum
        print *
        print *,'so4x', prox**2d0*so4x 
        print * ,'so4f',- prox**2d0*so4f* 1d0 
        print * ,'mgso4',- prox**2d0*so4f* k1mgso4*mgf 
        print * ,'naso4',- prox**2d0*so4f* k1naso4*naf
        print * ,'caso4',- prox**2d0*so4f* k1caso4*caf   
        print * ,'also4',- prox**2d0*so4f* k1also4*alf 
        print * ,'fe2so4',- prox**2d0*so4f* k1fe2so4*fe2f
        print * ,'fe3so4',- prox**2d0*so4f* k1fe3so4*fe3f 
        print *,'hso4',- prox**2d0*so4f* k1so4*prox 
        print * ,'kso4',- prox**2d0*so4f* k1kso4*kf 
        pause
        
    endif 
#endif 
        
! #ifdef debug 
    ! print *, 'v7_2 '
    ! print * , iter
    ! print *, 'f1',f1
    ! print *
    ! print *, 'df1',df1
    ! print *
    ! print *, 'df12',df12
    ! print *
    ! print *, 'f2',f2
    ! print *
    ! print *, 'df2',df2
    ! print *
    ! print *, 'df21',df21
    ! print *
    ! print *, 'prox',prox
    ! print *
    ! print *, 'so4f',so4f
    ! print *
! #endif 
        
        
    df1 = df1*prox
    df21 = df21*prox
    df2 = df2*so4f
    df12 = df12*so4f
    
    if (any(isnan(f1)).or.any(isnan(f2)).or.any(isnan(df1)).or.any(isnan(df2)) &
        & .or.any(isnan(df12)).or.any(isnan(df21))) then 
        print*,'found nan during the course of ph calc'
        print *,any(isnan(f1)),any(isnan(f2)),any(isnan(df1)),any(isnan(df2)) &
            & ,any(isnan(df12)),any(isnan(df21))
        print *,prox
        ph_error = .true.
        exit
        ! pause 
    endif 
    
    
    if (nmx/=nz) then 
        amx = 0d0
        ymx = 0d0
        
        ymx(1:nz) = f1
        ymx(nz+1:nmx) = f2
        
        do iz=1,nz
            amx(iz,iz)=df1(iz)
            amx(nz+iz,nz+iz)=df2(iz)
            amx(iz,nz+iz)=df12(iz)
            amx(nz+iz,iz)=df21(iz)
        enddo 
        ymx = -ymx
        
        call DGESV(nmx,int(1),amx,nmx,ipiv,ymx,nmx,info) 
        
        prox = prox*exp( ymx(1:nz) )
        so4f = so4f*exp( ymx(nz+1:nmx) )
        
        error = maxval(abs(exp( ymx )-1d0))
        if (isnan(error)) then 
            error = 1d4
            ph_error = .true.
            exit 
        endif 
    else 
        prox = prox*exp( -f1/df1 )
        error = maxval(abs(exp( -f1/df1 )-1d0))
        if (isnan(error)) error = 1d4
    endif 
    
    iter = iter + 1
    
    if (iter > 3000) then 
        print *,'iteration exceeds 3000'
        ph_error = .true.
        return
    endif 
enddo 
#ifdef timing 
call cpu_time( t2 )
print *, "cpu time:", t2-t1, "seconds [v7_2] per ph & SO4f soultion."
#endif 

ph_iter = iter

if (any(isnan(prox)) .or. any(prox<=0d0)) then     
    print *, (-log10(prox(iz)),iz=1,nz,nz/5)
    print*,'ph is nan or <= 0'
    ph_error = .true.
    ! stop
endif 
    
kf = kx/(1d0+k1kso4*so4f)

naf = nax/(1d0+k1naco3*k1*k2*kco2*pco2x/prox**2d0+k1nahco3*k1*k2*kco2*pco2x/prox+k1naso4*so4f)
    
caf = cax/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox+k1caso4*so4f)
    
mgf = mgx/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox+k1mgso4*so4f)
    
fe2f = fe2x/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox+k1fe2so4*so4f)
    
sif = six/(1d0+k1si/prox+k2si/prox**2d0)

alf = alx/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0+k1also4*so4f)

fe3f = fe3x/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0+k1fe3so4*so4f)

no3f = no3x/(1d0 + k1no3*prox)

#ifdef debug
call get_maqf_all( &
    & nz,nsp_aq_all,nsp_gas_all &
    & ,chraq_all,chrgas_all &
    & ,keqgas_h,keqaq_h,keqaq_c,keqaq_s,keqaq_no3 &
    & ,mgasx_loc,maqx_loc,prox,so4f &
    & ,dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2 &! output
    & ,maqf_loc  &! output
    & )
    
! print *
! print*,'k',maxval(abs(kf-maqf_loc(findloc(chraq_all,'k',dim=1),:)))
! print*,'na',maxval(abs(naf-maqf_loc(findloc(chraq_all,'na',dim=1),:)))
! print*,'ca',maxval(abs(caf-maqf_loc(findloc(chraq_all,'ca',dim=1),:)))
! print*,'mg',maxval(abs(mgf-maqf_loc(findloc(chraq_all,'mg',dim=1),:)))
! print*,'fe2',maxval(abs(fe2f-maqf_loc(findloc(chraq_all,'fe2',dim=1),:)))
! print*,'si',maxval(abs(sif-maqf_loc(findloc(chraq_all,'si',dim=1),:)))
! print*,'al',maxval(abs(alf-maqf_loc(findloc(chraq_all,'al',dim=1),:)))
! print*,'fe3',maxval(abs(fe3f-maqf_loc(findloc(chraq_all,'fe3',dim=1),:)))
! print*,'no3',maxval(abs(no3f-maqf_loc(findloc(chraq_all,'no3',dim=1),:)))
! print *
#endif 
       
if (print_cb) then 
    open(88,file = trim(adjustl(print_loc)),status='replace')
    write(88,*) ' z ',' h+ ',' oh- ' &
        & ,' no3- ', ' hno3 ' &
        & ,' nh4+ ',' na+ ',' naco3- ', ' nahco3 ', ' naso4- ', ' k+ ',' kso4- ' &
        & ,' so42- ', ' hso4- ', 'hco3- ', ' co32- ' &
        & ,' h4sio4 ',' h3sio4- ',' h2sio42- ' &
        & ,' mg2+ ', ' mg(oh)+ ', ' mgco3 ', 'mghco3+ ', 'mgso4 ' &
        & , ' ca2+ ', ' ca(oh)+ ', ' caco3 ', ' cahco3+ ', ' caso4 ' &
        & ,' al3+ ', ' al(oh)2+ ', ' al(oh)2+ ', ' al(oh)3 ', ' al(oh)4- ' , ' also4+ ' &
        & , ' fe22+ ', ' fe2(oh)+ ', ' fe2co3 ', ' fe2hco3+ ', ' fe2so4 ' &
        & ,' fe3+ ', ' fe3(oh)2+ ', ' fe3(oh)2+ ', ' fe3(oh)3 ', ' fe3(oh)4- ', ' fe3so4+ ' &
        & , ' total_charge ' 
    do iz=1,nz
        write(88,*) z(iz) &
        & ,prox(iz) &
        & ,kw/prox(iz) &
        & ,no3f(iz) &
        & ,no3f(iz)*k1no3*prox(iz) &
        & ,pnh3x(iz)*knh3/k1nh3*prox(iz) &
        & ,naf(iz) &
        & ,naf(iz)*k1naco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0 &
        & ,naf(iz)*k1nahco3*k1*k2*kco2*pco2x(iz)/prox(iz)     &
        & ,naf(iz)*k1naso4*so4f(iz)     &
        & ,kf(iz) &
        & ,kf(iz)*k1kso4*so4f(iz) &
        & ,so4f(iz) &
        & ,so4f(iz)*k1so4*prox(iz) &
        & ,k1*kco2*pco2x(iz)/prox(iz) &
        & ,k2*k1*kco2*pco2x(iz)/prox(iz)**2d0 &
        & ,sif(iz) &
        & ,sif(iz)*k1si/prox(iz) &
        & ,sif(iz)*k2si/prox(iz)**2d0 &
        & ,mgf(iz) &
        & ,mgf(iz)*k1mg/prox(iz)  &
        & ,mgf(iz)*k1mgco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0  &
        & ,mgf(iz)*k1mghco3*k1*k2*kco2*pco2x(iz)/prox(iz)  &
        & ,mgf(iz)*k1mgso4*so4f(iz)  &
        & ,caf(iz) &
        & ,caf(iz)*k1ca/prox(iz) &
        & ,caf(iz)*k1caco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0 &
        & ,caf(iz)*k1cahco3*k1*k2*kco2*pco2x(iz)/prox(iz) &
        & ,caf(iz)*k1caso4*so4f(iz) &
        & ,alf(iz) &
        & ,alf(iz)*k1al/prox(iz) &
        & ,alf(iz)*k2al/prox(iz)**2d0 &
        & ,alf(iz)*k3al/prox(iz)**3d0 &
        & ,alf(iz)*k4al/prox(iz)**4d0 &
        & ,alf(iz)*k1also4*so4f(iz) &
        & ,fe2f(iz) &
        & ,fe2f(iz)*k1fe2/prox(iz) &
        & ,fe2f(iz)*k1fe2co3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0 &
        & ,fe2f(iz)*k1fe2hco3*k1*k2*kco2*pco2x(iz)/prox(iz) &
        & ,fe2f(iz)*k1fe2so4*so4f(iz) &
        & ,fe3f(iz) &
        & ,fe3f(iz)*k1fe3/prox(iz) &
        & ,fe3f(iz)*k2fe3/prox(iz)**2d0 &
        & ,fe3f(iz)*k3fe3/prox(iz)**3d0 &
        & ,fe3f(iz)*k4fe3/prox(iz)**4d0 &
        & ,fe3f(iz)*k1fe3so4*so4f(iz) &
        ! charge balance 
        & ,1d0*prox(iz) &
        & +(-1d0)*kw/prox(iz) &
        & +(-1d0)*no3f(iz) &
        & +(0d0)*no3f(iz)*k1no3*prox(iz) &
        & +(1d0)*pnh3x(iz)*knh3/k1nh3*prox(iz) &
        & +(1d0)*naf(iz) &
        & +(-1d0)*naf(iz)*k1naco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0 &
        & +(0d0)*naf(iz)*k1nahco3*k1*k2*kco2*pco2x(iz)/prox(iz)      &
        & +(-1d0)*naf(iz)*k1naso4*so4f(iz)     &
        & +(1d0)*kf(iz) &
        & +(-1d0)*kf(iz)*k1kso4*so4f(iz) &
        & +(-2d0)*so4f(iz) &
        & +(-1d0)*so4f(iz)*k1so4*prox(iz) &
        & +(-1d0)*k1*kco2*pco2x(iz)/prox(iz) &
        & +(-2d0)*k2*k1*kco2*pco2x(iz)/prox(iz)**2d0 &
        & +(0d0)*sif(iz) &
        & +(-1d0)*sif(iz)*k1si/prox(iz) &
        & +(-2d0)*sif(iz)*k2si/prox(iz)**2d0 &
        & +(2d0)*mgf(iz) &
        & +(1d0)*mgf(iz)*k1mg/prox(iz)  &
        & +(0d0)*mgf(iz)*k1mgco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0  &
        & +(1d0)*mgf(iz)*k1mghco3*k1*k2*kco2*pco2x(iz)/prox(iz)  &
        & +(0d0)*mgf(iz)*k1mgso4*so4f(iz)  &
        & +(2d0)*caf(iz) &
        & +(1d0)*caf(iz)*k1ca/prox(iz) &
        & +(0d0)*caf(iz)*k1caco3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0 &
        & +(1d0)*caf(iz)*k1cahco3*k1*k2*kco2*pco2x(iz)/prox(iz) &
        & +(0d0)*caf(iz)*k1caso4*so4f(iz) &
        & +(3d0)*alf(iz) &
        & +(2d0)*alf(iz)*k1al/prox(iz) &
        & +(1d0)*alf(iz)*k2al/prox(iz)**2d0 &
        & +(0d0)*alf(iz)*k3al/prox(iz)**3d0 &
        & +(-1d0)*alf(iz)*k4al/prox(iz)**4d0 &
        & +(1d0)*alf(iz)*k1also4*so4f(iz) &
        & +(2d0)*fe2f(iz) &
        & +(1d0)*fe2f(iz)*k1fe2/prox(iz) &
        & +(0d0)*fe2f(iz)*k1fe2co3*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0 &
        & +(1d0)*fe2f(iz)*k1fe2hco3*k1*k2*kco2*pco2x(iz)/prox(iz) &
        & +(0d0)*fe2f(iz)*k1fe2so4*so4f(iz) &
        & +(3d0)*fe3f(iz) &
        & +(2d0)*fe3f(iz)*k1fe3/prox(iz) &
        & +(1d0)*fe3f(iz)*k2fe3/prox(iz)**2d0 &
        & +(0d0)*fe3f(iz)*k3fe3/prox(iz)**3d0 &
        & +(-1d0)*fe3f(iz)*k4fe3/prox(iz)**4d0 &
        & +(1d0)*fe3f(iz)*k1fe3so4*so4f(iz) 
    enddo 
    close(88)
endif 
            

endsubroutine calc_pH_v7_2_dev

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine calc_pH_v7_3( &
    & nz,kw,nsp_aq,nsp_gas,nsp_aq_all,nsp_gas_all,nsp_aq_cnst,nsp_gas_cnst &! input 
    & ,chraq,chraq_cnst,chraq_all,chrgas,chrgas_cnst,chrgas_all &!input
    & ,maqx,maqc,mgasx,mgasc,keqgas_h,keqaq_h,keqaq_c,keqaq_s,maqth_all,keqaq_no3,keqaq_nh3 &! input
    & ,print_cb,print_loc,z &! input 
    & ,dprodmaq_all,dprodmgas_all,dso4fdmaq_all,dso4fdmgas_all &! output
    & ,prox,ph_error,so4f,ph_iter &! output
    & ) 
! solving charge balance & so4 species balance
implicit none
integer,intent(in)::nz
real(kind=8),intent(in)::kw
real(kind=8) so4th
real(kind=8),dimension(nz)::so4x
real(kind=8),dimension(nz),intent(in)::z
real(kind=8),dimension(nz),intent(inout)::prox,so4f
logical,intent(out)::ph_error

real(kind=8),dimension(nz)::df1,f1,f2,df2,df21,df12
real(kind=8) error,tol,dconc,ph_add_order 
integer iter,iz,ispa,ispg

integer,intent(in)::nsp_aq,nsp_gas,nsp_aq_all,nsp_gas_all,nsp_aq_cnst,nsp_gas_cnst
character(5),dimension(nsp_aq),intent(in)::chraq
character(5),dimension(nsp_aq_cnst),intent(in)::chraq_cnst
character(5),dimension(nsp_aq_all),intent(in)::chraq_all
character(5),dimension(nsp_gas),intent(in)::chrgas
character(5),dimension(nsp_gas_cnst),intent(in)::chrgas_cnst
character(5),dimension(nsp_gas_all),intent(in)::chrgas_all
real(kind=8),dimension(nsp_aq,nz),intent(in)::maqx
real(kind=8),dimension(nsp_aq_cnst,nz),intent(in)::maqc
real(kind=8),dimension(nsp_gas,nz),intent(in)::mgasx
real(kind=8),dimension(nsp_gas_cnst,nz),intent(in)::mgasc
real(kind=8),dimension(nsp_gas_all,3),intent(in)::keqgas_h
real(kind=8),dimension(nsp_aq_all,4),intent(in)::keqaq_h
real(kind=8),dimension(nsp_aq_all,2),intent(in)::keqaq_c
real(kind=8),dimension(nsp_aq_all,2),intent(in)::keqaq_s
real(kind=8),dimension(nsp_aq_all,2),intent(in)::keqaq_nh3
real(kind=8),dimension(nsp_aq_all,2),intent(in)::keqaq_no3
real(kind=8),dimension(nsp_aq_all),intent(in)::maqth_all

real(kind=8),dimension(nsp_aq_all)::base_charge
real(kind=8),dimension(nsp_aq_all,nz)::maqx_loc,maqf_loc
real(kind=8),dimension(nsp_aq_all,nz)::dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2
real(kind=8),dimension(nsp_gas_all,nz)::mgasx_loc
real(kind=8),dimension(nsp_aq_all,nz)::df1dmaq,df2dmaq
real(kind=8),dimension(nsp_gas_all,nz)::df1dmgas,df2dmgas

real(kind=8),dimension(nsp_aq_all,nz),intent(out)::dprodmaq_all,dso4fdmaq_all
real(kind=8),dimension(nsp_gas_all,nz),intent(out)::dprodmgas_all,dso4fdmgas_all

real(kind=8),dimension(nsp_aq_all,nz)::dmaq
real(kind=8),dimension(nsp_gas_all,nz)::dmgas
real(kind=8),dimension(nz)::df1_dum,f1_dum,f2_dum,df2_dum,df21_dum,df12_dum
real(kind=8),dimension(nsp_aq_all,nz)::df1dmaq_dum,df2dmaq_dum
real(kind=8),dimension(nsp_gas_all,nz)::df1dmgas_dum,df2dmgas_dum

integer,intent(out)::ph_iter

logical,intent(in)::print_cb
character(500),intent(in)::print_loc
logical so4_error,print_res

real(kind=8),allocatable::amx(:,:),ymx(:)
integer,allocatable::ipiv(:)
integer info,nmx


error = 1d4
tol = 1d-6
dconc = 1d-9
ph_add_order = 2d0

! prox = 1d0 
iter = 0

if (any(isnan(maqx)) .or. any(isnan(maqc))) then 
    print*,'nan in input aqueosu species'
    stop
endif 

call get_maqgasx_all( &
    & nz,nsp_aq_all,nsp_gas_all,nsp_aq,nsp_gas,nsp_aq_cnst,nsp_gas_cnst &
    & ,chraq,chraq_all,chraq_cnst,chrgas,chrgas_all,chrgas_cnst &
    & ,maqx,mgasx,maqc,mgasc &
    & ,maqx_loc,mgasx_loc  &! output
    & )
    
call get_base_charge( &
    & nsp_aq_all & 
    & ,chraq_all & 
    & ,base_charge &! output 
    & )

so4x = maqx_loc(findloc(chraq_all,'so4',dim=1),:)

so4th = maqth_all(findloc(chraq_all,'so4',dim=1))

! so4f  = so4x 

nmx = 2*nz
! if (all(so4x==0d0)) then 
if (all(so4x<=so4th)) then 
    nmx = nz
endif  

if (allocated(amx)) deallocate(amx)
if (allocated(ymx)) deallocate(ymx)
if (allocated(ipiv)) deallocate(ipiv)
allocate(amx(nmx,nmx),ymx(nmx),ipiv(nmx))

ph_error = .false.

print_res = .false.

! print*,'calc_pH'
if (.not. print_cb) then
    ! obtaining ph and so4f from scratch
  
    so4f  = so4x 
    prox = 1d0 
    do while (error > tol)
        ! free SO42- (for simplicity only consider XSO4 complex where X is a cation)
        
        call get_maqf_all( &
            & nz,nsp_aq_all,nsp_gas_all &
            & ,chraq_all,chrgas_all &
            & ,keqgas_h,keqaq_h,keqaq_c,keqaq_s,keqaq_no3 &
            & ,mgasx_loc,maqx_loc,prox,so4f &
            & ,dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2 &! output
            & ,maqf_loc  &! output
            & )
        
        ! call calc_charge( &
            ! & nz,nsp_aq_all,nsp_gas_all &
            ! & ,chraq_all,chrgas_all &
            ! & ,kw,keqgas_h,keqaq_h,keqaq_c,keqaq_s  &
            ! & ,mgasx_loc,maqf_loc &
            ! & ,dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2 &
            ! & ,z,prox,so4f &
            ! & ,print_loc,print_res,ph_add_order &
            ! & ,df1,df12,df1dmaq,df1dmgas &!output
            ! & ,f1 &! output
            ! & )
        ! f1 = f1*prox**2d0
        ! df1 = 2d0*prox*f1 + df1*prox**2d0
        ! df12 = df12*prox**2d0
        
        ! call calc_so4_balance( &
            ! & nz,nsp_aq_all,nsp_gas_all &
            ! & ,chraq_all,chrgas_all &
            ! & ,keqaq_h,keqaq_s  &
            ! & ,maqf_loc &
            ! & ,dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2 &
            ! & ,prox,so4f,so4x &
            ! & ,ph_add_order &
            ! & ,df2,df21,df2dmaq,df2dmgas &! output
            ! & ,f2 &! output
            ! & )
        ! f2 = f2*prox**2d0
        ! df2 = df2*prox**2d0
        ! df21 = f2*2d0*prox + df21*prox**2d0
        
        call calc_charge_so4_balance( &
            & nz,nsp_aq_all,nsp_gas_all &
            & ,chraq_all,chrgas_all &
            & ,kw,keqgas_h,keqaq_h,keqaq_c,keqaq_s  &
            & ,base_charge &
            & ,mgasx_loc,maqf_loc &
            & ,dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2 &
            & ,z,prox,so4f,so4x &
            & ,print_loc,print_res,ph_add_order &
            & ,f1,df1,df12,df1dmaq,df1dmgas &!output
            & ,f2,df2,df21,df2dmaq,df2dmgas &!output
            & )
        
        df1 = df1*prox
        df21 = df21*prox
        df2 = df2*so4f
        df12 = df12*so4f
        
        if (any(isnan(f1)).or.any(isnan(f2)).or.any(isnan(df1)).or.any(isnan(df2)) &
            & .or.any(isnan(df12)).or.any(isnan(df21))) then 
            print*,'found nan during the course of ph calc'
            print *,any(isnan(f1)),any(isnan(f2)),any(isnan(df1)),any(isnan(df2)) &
                & ,any(isnan(df12)),any(isnan(df21))
            print *,prox
            ph_error = .true.
            exit
            ! pause 
        endif 
        
        
        if (nmx/=nz) then 
            amx = 0d0
            ymx = 0d0
            
            ymx(1:nz) = f1(:)
            ymx(nz+1:nmx) = f2(:)
            
            do iz=1,nz
                amx(iz,iz)=df1(iz)
                amx(nz+iz,nz+iz)=df2(iz)
                amx(iz,nz+iz)=df12(iz)
                amx(nz+iz,iz)=df21(iz)
            enddo 
            ymx = -ymx
            
            call DGESV(nmx,int(1),amx,nmx,ipiv,ymx,nmx,info) 
            
            prox = prox*exp( ymx(1:nz) )
            so4f = so4f*exp( ymx(nz+1:nmx) )
            
            error = maxval(abs(exp( ymx )-1d0))
            if (isnan(error) .or. info/=0) then 
                error = 1d4
                ph_error = .true.
                exit 
            endif 
        else 
            prox = prox*exp( -f1/df1 )
            error = maxval(abs(exp( -f1/df1 )-1d0))
            if (isnan(error)) error = 1d4
        endif 
        
        iter = iter + 1
        
        if (iter > 3000) then 
            print *,'iteration exceeds 3000'
            ph_error = .true.
            return
        endif 
    enddo  
endif 

ph_iter = iter

if (any(isnan(prox)) .or. any(prox<=0d0)) then     
    print *, (-log10(prox(iz)),iz=1,nz,nz/5)
    print*,'ph is nan or <= zero'
    ph_error = .true.
    ! stop
endif 

call get_maqf_all( &
    & nz,nsp_aq_all,nsp_gas_all &
    & ,chraq_all,chrgas_all &
    & ,keqgas_h,keqaq_h,keqaq_c,keqaq_s,keqaq_no3 &
    & ,mgasx_loc,maqx_loc,prox,so4f &
    & ,dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2 &! output
    & ,maqf_loc  &! output
    & )

if (print_cb) print_res = .true.

call calc_charge( &
    & nz,nsp_aq_all,nsp_gas_all &
    & ,chraq_all,chrgas_all &
    & ,kw,keqgas_h,keqaq_h,keqaq_c,keqaq_s  &
    & ,mgasx_loc,maqf_loc &
    & ,dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2 &
    & ,z,prox,so4f &
    & ,print_loc,print_res,ph_add_order &
    & ,df1,df12,df1dmaq,df1dmgas &!output
    & ,f1 &! output
    & )

    
call calc_so4_balance( &
    & nz,nsp_aq_all,nsp_gas_all &
    & ,chraq_all,chrgas_all &
    & ,keqaq_h,keqaq_s  &
    & ,maqf_loc &
    & ,dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2 &
    & ,prox,so4f,so4x &
    & ,ph_add_order &
    & ,df2,df21,df2dmaq,df2dmgas &! output
    & ,f2 &! output
    & )    

! call calc_charge_so4_balance( &
    ! & nz,nsp_aq_all,nsp_gas_all &
    ! & ,chraq_all,chrgas_all &
    ! & ,kw,keqgas_h,keqaq_h,keqaq_c,keqaq_s  &
    ! & ,base_charge &
    ! & ,mgasx_loc,maqf_loc &
    ! & ,dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2 &
    ! & ,z,prox,so4f,so4x &
    ! & ,print_loc,print_res,ph_add_order &
    ! & ,f1,df1,df12,df1dmaq,df1dmgas &!output
    ! & ,f2,df2,df21,df2dmaq,df2dmgas &!output
    ! & )    
    
do ispa=1,nsp_aq_all
    dmaq = 0d0
    dmaq(ispa,:) = dconc!*maqx_loc(ispa,:)
    call get_maqf_all( &
        & nz,nsp_aq_all,nsp_gas_all &
        & ,chraq_all,chrgas_all &
        & ,keqgas_h,keqaq_h,keqaq_c,keqaq_s,keqaq_no3 &
        & ,mgasx_loc,maqx_loc+dmaq,prox,so4f &
        & ,dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2 &! output
        & ,maqf_loc  &! output
        & )
        
    call calc_charge( &
        & nz,nsp_aq_all,nsp_gas_all &
        & ,chraq_all,chrgas_all &
        & ,kw,keqgas_h,keqaq_h,keqaq_c,keqaq_s  &
        & ,mgasx_loc,maqf_loc &
        & ,dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2 &
        & ,z,prox,so4f &
        & ,print_loc,print_res,ph_add_order &
        & ,df1_dum,df12_dum,df1dmaq_dum,df1dmgas_dum &!output
        & ,f1_dum &! output
        & )
    
    call calc_so4_balance( &
        & nz,nsp_aq_all,nsp_gas_all &
        & ,chraq_all,chrgas_all &
        & ,keqaq_h,keqaq_s  &
        & ,maqf_loc &
        & ,dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2 &
        & ,prox,so4f,so4x &
        & ,ph_add_order &
        & ,df2_dum,df21_dum,df2dmaq_dum,df2dmgas_dum &! output
        & ,f2_dum &! output
        & )   
    dprodmaq_all(ispa,:) = -f1_dum/df1_dum/dconc!/maqx_loc(ispa,:) 
    dso4fdmaq_all(ispa,:) = -f2_dum/df2_dum/dconc!/maqx_loc(ispa,:) 
enddo 
    
do ispg=1,nsp_gas_all
    dmgas = 0d0
    dmgas(ispg,:) = dconc!*mgasx_loc(ispg,:)
    call get_maqf_all( &
        & nz,nsp_aq_all,nsp_gas_all &
        & ,chraq_all,chrgas_all &
        & ,keqgas_h,keqaq_h,keqaq_c,keqaq_s,keqaq_no3 &
        & ,mgasx_loc+dmgas,maqx_loc,prox,so4f &
        & ,dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2 &! output
        & ,maqf_loc  &! output
        & )
        
    call calc_charge( &
        & nz,nsp_aq_all,nsp_gas_all &
        & ,chraq_all,chrgas_all &
        & ,kw,keqgas_h,keqaq_h,keqaq_c,keqaq_s  &
        & ,mgasx_loc+dmgas,maqf_loc &
        & ,dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2 &
        & ,z,prox,so4f &
        & ,print_loc,print_res,ph_add_order &
        & ,df1_dum,df12_dum,df1dmaq_dum,df1dmgas_dum &!output
        & ,f1_dum &! output
        & )
    
    call calc_so4_balance( &
        & nz,nsp_aq_all,nsp_gas_all &
        & ,chraq_all,chrgas_all &
        & ,keqaq_h,keqaq_s  &
        & ,maqf_loc &
        & ,dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2 &
        & ,prox,so4f,so4x &
        & ,ph_add_order &
        & ,df2_dum,df21_dum,df2dmaq_dum,df2dmgas_dum &! output
        & ,f2_dum &! output
        & )   
    dprodmgas_all(ispg,:) = -f1_dum/df1_dum/dconc!/mgasx_loc(ispg,:)  
    dso4fdmgas_all(ispg,:) = -f2_dum/df2_dum/dconc !/mgasx_loc(ispg,:)
enddo 
! 
! solving two equations analytically:
! df1/dph * dph/dmsp + df1/dso4f * dso4f/dmsp + df1/dmsp = 0 
! df2/dph * dph/dmsp + df2/dso4f * dso4f/dmsp + df2/dmsp = 0 
! using the variables in this subroutine and defining x = dph/dmsp and y = dso4f/dmsp
! df1 * x + df12 * y + df1dmsp = 0
! df21 * x + df2 * y + df2dmsp = 0
! 
do ispa = 1, nsp_aq_all
    dprodmaq_all(ispa,:) = - (df2*df1dmaq(ispa,:) - df12*df2dmaq(ispa,:))/(df2*df1 - df12*df21)   
    dso4fdmaq_all(ispa,:) = - ( df21*df1dmaq(ispa,:) - df1*df2dmaq(ispa,:) )/(df21*df12 - df1*df2 ) 
enddo 

do ispg = 1, nsp_gas_all
    dprodmgas_all(ispg,:) = - (df2*df1dmgas(ispg,:) - df12*df2dmgas(ispg,:) )/(df2*df1 -df12*df21)
    dso4fdmgas_all(ispg,:) = - ( df21*df1dmgas(ispg,:) - df1*df2dmgas(ispg,:) )/(df21*df12 - df1*df2 )  
    ! dso4fdmgas_all(ispg,:) = - df1dmgas(ispg,:)/df12
    ! if (chrgas_all(ispg)=='pco2') then 
        ! print *,'df1dmgas(ispg,:)/df1'
        ! print *,df1dmgas(ispg,:)/df1
        ! print * 
        ! print *,'df2dmgas(ispg,:)/df21'
        ! print *,df2dmgas(ispg,:)/df21
        ! print * 
        ! print *,'dprodmgas_all(ispg,:)'
        ! print *,dprodmgas_all(ispg,:)
        ! print *  
        ! print *, '------------'  
        ! print *  
        ! print *,'df2dmgas(ispg,:)/df2'
        ! print *,df2dmgas(ispg,:)/df2
        ! print * 
        ! print *,'df1dmgas(ispg,:)/df12'
        ! print *,df1dmgas(ispg,:)/df12
        ! print * 
        ! print *,'dso4fdmgas_all(ispg,:)'
        ! print *,dso4fdmgas_all(ispg,:)
        ! print * 
    ! endif 
enddo 

endsubroutine calc_pH_v7_3

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine calc_pH_v7_4( &
    & nz,kw,nsp_aq,nsp_gas,nsp_aq_all,nsp_gas_all,nsp_aq_cnst,nsp_gas_cnst &! input 
    & ,chraq,chraq_cnst,chraq_all,chrgas,chrgas_cnst,chrgas_all &!input
    & ,maqx,maqc,mgasx,mgasc,keqgas_h,keqaq_h,keqaq_c,keqaq_s,maqth_all,keqaq_no3,keqaq_nh3 &! input
    & ,print_cb,print_loc,z &! input 
    & ,dprodmaq_all,dprodmgas_all,dso4fdmaq_all,dso4fdmgas_all &! output
    & ,prox,ph_error,so4f,ph_iter &! output
    & ) 
! solving charge balance & so4 species balance
implicit none
integer,intent(in)::nz
real(kind=8),intent(in)::kw
real(kind=8) so4th
real(kind=8),dimension(nz)::so4x,pco2x,pnh3x
real(kind=8),dimension(nz),intent(in)::z
real(kind=8),dimension(nz),intent(inout)::prox,so4f
logical,intent(out)::ph_error

real(kind=8),dimension(nz)::df1,f1,f2,df2,df21,df12,f1_chk
real(kind=8) error,tol,dconc,ph_add_order 
integer iter,iz,ispa,ispg

integer,intent(in)::nsp_aq,nsp_gas,nsp_aq_all,nsp_gas_all,nsp_aq_cnst,nsp_gas_cnst
character(5),dimension(nsp_aq),intent(in)::chraq
character(5),dimension(nsp_aq_cnst),intent(in)::chraq_cnst
character(5),dimension(nsp_aq_all),intent(in)::chraq_all
character(5),dimension(nsp_gas),intent(in)::chrgas
character(5),dimension(nsp_gas_cnst),intent(in)::chrgas_cnst
character(5),dimension(nsp_gas_all),intent(in)::chrgas_all
real(kind=8),dimension(nsp_aq,nz),intent(in)::maqx
real(kind=8),dimension(nsp_aq_cnst,nz),intent(in)::maqc
real(kind=8),dimension(nsp_gas,nz),intent(in)::mgasx
real(kind=8),dimension(nsp_gas_cnst,nz),intent(in)::mgasc
real(kind=8),dimension(nsp_gas_all,3),intent(in)::keqgas_h
real(kind=8),dimension(nsp_aq_all,4),intent(in)::keqaq_h
real(kind=8),dimension(nsp_aq_all,2),intent(in)::keqaq_c
real(kind=8),dimension(nsp_aq_all,2),intent(in)::keqaq_s
real(kind=8),dimension(nsp_aq_all,2),intent(in)::keqaq_nh3
real(kind=8),dimension(nsp_aq_all,2),intent(in)::keqaq_no3
real(kind=8),dimension(nsp_aq_all),intent(in)::maqth_all

real(kind=8),dimension(nsp_aq_all)::base_charge
real(kind=8),dimension(nsp_aq_all,nz)::maqx_loc,maqf_loc
real(kind=8),dimension(nsp_aq_all,nz)::dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2
real(kind=8),dimension(nsp_gas_all,nz)::mgasx_loc
real(kind=8),dimension(nsp_aq_all,nz)::df1dmaq,df2dmaq
real(kind=8),dimension(nsp_gas_all,nz)::df1dmgas,df2dmgas

real(kind=8),dimension(nsp_aq_all,nz),intent(out)::dprodmaq_all,dso4fdmaq_all
real(kind=8),dimension(nsp_gas_all,nz),intent(out)::dprodmgas_all,dso4fdmgas_all

real(kind=8),dimension(nsp_aq_all,nz)::dmaq
real(kind=8),dimension(nsp_gas_all,nz)::dmgas
real(kind=8),dimension(nz)::df1_dum,f1_dum,f2_dum,df2_dum,df21_dum,df12_dum
real(kind=8),dimension(nsp_aq_all,nz)::df1dmaq_dum,df2dmaq_dum
real(kind=8),dimension(nsp_gas_all,nz)::df1dmgas_dum,df2dmgas_dum

integer,intent(out)::ph_iter

logical,intent(in)::print_cb
character(500),intent(in)::print_loc
logical so4_error,print_res

integer ipco2,ipnh3,ispa_h,ispa_c,ispa_s
real(kind=8) kco2,k1,k2,knh3,k1nh3,ss_add,rspa_h,rspa_s

character(1) chrint

integer ieqgas_h0,ieqgas_h1,ieqgas_h2
data ieqgas_h0,ieqgas_h1,ieqgas_h2/1,2,3/

real(kind=8),allocatable::amx(:,:),ymx(:)
integer,allocatable::ipiv(:)
integer info,nmx

! external DGESV
#ifdef timing
real(kind=8) :: t1, t2
#endif 

error = 1d4
tol = 1d-6
dconc = 1d-9
ph_add_order = 2d0

! prox = 1d0 
iter = 0

if (any(isnan(maqx)) .or. any(isnan(maqc))) then 
    print*,'nan in input aqueosu species'
    stop
endif 

call get_maqgasx_all( &
    & nz,nsp_aq_all,nsp_gas_all,nsp_aq,nsp_gas,nsp_aq_cnst,nsp_gas_cnst &
    & ,chraq,chraq_all,chraq_cnst,chrgas,chrgas_all,chrgas_cnst &
    & ,maqx,mgasx,maqc,mgasc &
    & ,maqx_loc,mgasx_loc  &! output
    & )
    
call get_base_charge( &
    & nsp_aq_all & 
    & ,chraq_all & 
    & ,base_charge &! output 
    & )

so4x = maqx_loc(findloc(chraq_all,'so4',dim=1),:)

so4th = maqth_all(findloc(chraq_all,'so4',dim=1))


ipco2 = findloc(chrgas_all,'pco2',dim=1)
ipnh3 = findloc(chrgas_all,'pnh3',dim=1)

kco2 = keqgas_h(ipco2,ieqgas_h0)
k1 = keqgas_h(ipco2,ieqgas_h1)
k2 = keqgas_h(ipco2,ieqgas_h2)

pco2x = mgasx_loc(ipco2,:)


knh3 = keqgas_h(ipnh3,ieqgas_h0)
k1nh3 = keqgas_h(ipnh3,ieqgas_h1)

pnh3x = mgasx_loc(ipnh3,:)

ss_add = ph_add_order


print_res = print_cb

if (print_res) open(88,file = trim(adjustl(print_loc)),status='replace')

! so4f  = so4x 

nmx = 2*nz
! if (all(so4x==0d0)) then 
if (all(so4x<=so4th)) then 
    nmx = nz
#ifdef debug
    print * , 'v7_3'
    print *, 'so4f is assumed to be constant'
#endif 
endif  

if (allocated(amx)) deallocate(amx)
if (allocated(ymx)) deallocate(ymx)
if (allocated(ipiv)) deallocate(ipiv)
allocate(amx(nmx,nmx),ymx(nmx),ipiv(nmx))

ph_error = .false.

#ifdef debug
    print *, 'v7_4 nmx = :',nmx
#endif 
! print*,'calc_pH'
if (.not. print_cb) then
    ! obtaining ph and so4f from scratch
  
    so4f  = so4x 
    prox = 1d0 
#ifdef timing
    call cpu_time( t1 )
#endif 
    do while (error > tol)
        ! free SO42- (for simplicity only consider XSO4 complex where X is a cation)
        
        call get_maqf_all( &
            & nz,nsp_aq_all,nsp_gas_all &
            & ,chraq_all,chrgas_all &
            & ,keqgas_h,keqaq_h,keqaq_c,keqaq_s,keqaq_no3 &
            & ,mgasx_loc,maqx_loc,prox,so4f &
            & ,dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2 &! output
            & ,maqf_loc  &! output
            & )
        
        f1 = 0d0
        df1 = 0d0
        df12 = 0d0
        df1dmaq = 0d0
        df1dmgas = 0d0

        f1 = f1 + prox**(ss_add+1d0) - kw*prox**(ss_add-1d0)
        df1 = df1 + (ss_add+1d0)*prox**ss_add - kw*(ss_add-1d0)*prox**(ss_add-2d0)
        if (print_res) write(88,'(3A11)', advance='no') 'z','h', 'oh'

        ! adding charges coming from aq species in eq with gases
        ! pCO2
        f1 = f1  -  k1*kco2*pco2x*prox**(ss_add-1d0)  -  2d0*k2*k1*kco2*pco2x*prox**(ss_add-2d0)
        df1 = df1  -  k1*kco2*pco2x*(ss_add-1d0)*prox**(ss_add-2d0)  -  2d0*k2*k1*kco2*pco2x*(ss_add-2d0)*prox**(ss_add-3d0)
        df1dmgas(ipco2,:) = df1dmgas(ipco2,:) -  k1*kco2*1d0*prox**(ss_add-1d0)  -  2d0*k2*k1*kco2*1d0*prox**(ss_add-2d0)
        if (print_res) write(88,'(2A11)', advance='no') 'hco3','co3'
        ! pNH3
        f1 = f1  +  pnh3x*knh3/k1nh3*prox**(ss_add+1d0)
        df1 = df1  +  pnh3x*knh3/k1nh3*(ss_add+1d0)*prox**ss_add
        df1dmgas(ipnh3,:) = df1dmgas(ipnh3,:)  +  1d0*knh3/k1nh3*prox**(ss_add+1d0)
        if (print_res) write(88,'(A11)', advance='no') 'nh4'

        !### SO4 mass balance ###
        f2 = 0d0
        df2 = 0d0
        df21 = 0d0
        df2dmaq = 0d0
        df2dmgas = 0d0

        f2 = so4x*prox**ss_add - so4f*prox**ss_add
        df2 = - 1d0*prox**ss_add
        df21 = so4x*ss_add*prox**(ss_add-1d0) - so4f*ss_add*prox**(ss_add-1d0)
        df2dmaq(findloc(chraq_all,'so4',dim=1),:) =  1d0*prox**ss_add 
        !### SO4 mass balance ###

        do ispa = 1, nsp_aq_all
            
            f1 = f1 + base_charge(ispa)*maqf_loc(ispa,:)*prox**(ss_add)
            df1 = df1 + ( &
                & + base_charge(ispa)*dmaqf_dpro(ispa,:)*prox**(ss_add)  &
                & + base_charge(ispa)*maqf_loc(ispa,:)*(ss_add)*prox**(ss_add-1d0)  &
                & )
            df12 = df12 + base_charge(ispa)*dmaqf_dso4f(ispa,:)*prox**(ss_add) 
            df1dmaq(ispa,:) = df1dmaq(ispa,:) + base_charge(ispa)*dmaqf_dmaq(ispa,:)*prox**(ss_add) 
            df1dmgas(ipco2,:) = df1dmgas(ipco2,:) + base_charge(ispa)*dmaqf_dpco2(ispa,:) *prox**(ss_add)
            if (print_res) write(88,'(A11)', advance='no') trim(adjustl(chraq_all(ispa)))
            
            ! annions
            if (trim(adjustl(chraq_all(ispa)))=='no3' .or. trim(adjustl(chraq_all(ispa)))=='so4') then 
                
                ! account for speces associated with H+
                do ispa_h = 1,4
                    if ( keqaq_h(ispa,ispa_h) > 0d0) then 
                        rspa_h = real(ispa_h,kind=8)
                        f1 = f1 + (base_charge(ispa) + rspa_h)*keqaq_h(ispa,ispa_h)*maqf_loc(ispa,:)*prox**(rspa_h+ss_add)
                        df1 = df1 + ( & 
                            & + (base_charge(ispa) + rspa_h) &
                            &        *keqaq_h(ispa,ispa_h)*maqf_loc(ispa,:)*(rspa_h+ss_add)*prox**(rspa_h+ss_add-1d0) &
                            & + (base_charge(ispa) + rspa_h)*keqaq_h(ispa,ispa_h)*dmaqf_dpro(ispa,:)*prox**(rspa_h+ss_add) &
                            & )
                        df12 = df12 + (& 
                            & + (base_charge(ispa) + rspa_h)*keqaq_h(ispa,ispa_h)*dmaqf_dso4f(ispa,:)*prox**(rspa_h+ss_add) &
                            & )
                        df1dmaq(ispa,:) = df1dmaq(ispa,:) + (& 
                            & + (base_charge(ispa) + rspa_h)*keqaq_h(ispa,ispa_h)*dmaqf_dmaq(ispa,:)*prox**(rspa_h+ss_add) &
                            & )
                        df1dmgas(ipco2,:) = df1dmgas(ipco2,:) + (& 
                            & + (base_charge(ispa) + rspa_h)*keqaq_h(ispa,ispa_h)*dmaqf_dpco2(ispa,:)*prox**(rspa_h+ss_add) &
                            & )
                        if (print_res) then 
                            write(chrint,'(I1)') ispa_h
                            write(88,'(A11)', advance='no') 'h'//trim(adjustl(chrint))//trim(adjustl(chraq_all(ispa)))
                        endif 
                        
                        ! ### SO4 mass balance
                        ! account for SO4 association with H+
                        if ( trim(adjustl(chraq_all(ispa)))=='so4') then 
                            f2 = f2 - keqaq_h(ispa,ispa_h)*so4f*prox**(rspa_h+ss_add)
                            df2 = df2 - keqaq_h(ispa,ispa_h)*1d0*prox**(rspa_h+ss_add)
                            df21 = df21 - keqaq_h(ispa,ispa_h)*so4f*(rspa_h+ss_add)*prox**(rspa_h+ss_add-1d0)
                        endif 
                        !### SO4 mass balance ###
                        
                    endif 
                enddo 
            ! cations
            else 
                ! account for hydrolysis speces
                do ispa_h = 1,4
                    if ( keqaq_h(ispa,ispa_h) > 0d0) then 
                        rspa_h = real(ispa_h,kind=8)
                        f1 = f1 + (base_charge(ispa) - rspa_h)*keqaq_h(ispa,ispa_h)*maqf_loc(ispa,:)*prox**(ss_add-rspa_h)
                        df1 = df1 + ( &
                            & + (base_charge(ispa) - rspa_h) &
                            &       *keqaq_h(ispa,ispa_h)*maqf_loc(ispa,:)*(ss_add-rspa_h)*prox**(ss_add-rspa_h-1d0) &
                            & + (base_charge(ispa) - rspa_h)*keqaq_h(ispa,ispa_h)*dmaqf_dpro(ispa,:)*prox**(ss_add-rspa_h) &
                            & )
                        df12 = df12 + ( &
                            & + (base_charge(ispa) - rspa_h)*keqaq_h(ispa,ispa_h)*dmaqf_dso4f(ispa,:)*prox**(ss_add-rspa_h) &
                            & )
                        df1dmaq(ispa,:) = df1dmaq(ispa,:) + ( &
                            & + (base_charge(ispa) - rspa_h)*keqaq_h(ispa,ispa_h)*dmaqf_dmaq(ispa,:)*prox**(ss_add-rspa_h) &
                            & )
                        df1dmgas(ipco2,:) = df1dmgas(ipco2,:) + ( &
                            & + (base_charge(ispa) - rspa_h)*keqaq_h(ispa,ispa_h)*dmaqf_dpco2(ispa,:)*prox**(ss_add-rspa_h) &
                            & )
                        if (print_res) then 
                            write(chrint,'(I1)') ispa_h
                            write(88,'(A11)', advance='no') trim(adjustl(chraq_all(ispa)))//'(oh)'//trim(adjustl(chrint))
                        endif 
                    endif 
                enddo 
                ! account for species associated with CO3-- (ispa_c =1) and HCO3- (ispa_c =2)
                do ispa_c = 1,2
                    if ( keqaq_c(ispa,ispa_c) > 0d0) then 
                        if (ispa_c == 1) then ! with CO3--
                            f1 = f1 + &
                                & (base_charge(ispa)-2d0)*keqaq_c(ispa,ispa_c)*maqf_loc(ispa,:)*k1*k2*kco2*pco2x*prox**(ss_add-2d0)
                            df1 = df1 + ( & 
                                & + (base_charge(ispa)-2d0) &
                                &   *keqaq_c(ispa,ispa_c)*maqf_loc(ispa,:)*k1*k2*kco2*pco2x*(ss_add-2d0)*prox**(ss_add-3d0) &
                                & + (base_charge(ispa)-2d0) &
                                &   *keqaq_c(ispa,ispa_c)*dmaqf_dpro(ispa,:)*k1*k2*kco2*pco2x*prox**(ss_add-2d0) &
                                & )
                            df12 = df12 + ( & 
                                & + (base_charge(ispa)-2d0) &
                                &   *keqaq_c(ispa,ispa_c)*dmaqf_dso4f(ispa,:)*k1*k2*kco2*pco2x*prox**(ss_add-2d0) &
                                & )
                            df1dmaq(ispa,:) = df1dmaq(ispa,:) + ( & 
                                & + (base_charge(ispa)-2d0) &
                                &   *keqaq_c(ispa,ispa_c)*dmaqf_dmaq(ispa,:)*k1*k2*kco2*pco2x*prox**(ss_add-2d0) &
                                & )
                            df1dmgas(ipco2,:) = df1dmgas(ipco2,:) + ( & 
                                & + (base_charge(ispa)-2d0) &
                                &   *keqaq_c(ispa,ispa_c)*dmaqf_dpco2(ispa,:)*k1*k2*kco2*pco2x*prox**(ss_add-2d0) &
                                & + (base_charge(ispa)-2d0) &
                                &   *keqaq_c(ispa,ispa_c)*maqf_loc(ispa,:)*k1*k2*kco2*1d0*prox**(ss_add-2d0) &
                                & )
                            if (print_res) write(88,'(A11)', advance='no') trim(adjustl(chraq_all(ispa)))//'(co3)'
                        elseif (ispa_c == 2) then ! with HCO3-
                            f1 = f1 + &
                                & (base_charge(ispa)-1d0)*keqaq_c(ispa,ispa_c)*maqf_loc(ispa,:)*k1*k2*kco2*pco2x*prox**(ss_add-1d0)
                            df1 = df1 + ( & 
                                & + (base_charge(ispa)-1d0) &
                                &       *keqaq_c(ispa,ispa_c)*maqf_loc(ispa,:)*k1*k2*kco2*pco2x*(ss_add-1d0)*prox**(ss_add-2d0) &
                                & + (base_charge(ispa)-1d0) &
                                &       *keqaq_c(ispa,ispa_c)*dmaqf_dpro(ispa,:)*k1*k2*kco2*pco2x*prox**(ss_add-1d0) &
                                & )
                            df12 = df12 + ( & 
                                & + (base_charge(ispa)-1d0) &
                                &       *keqaq_c(ispa,ispa_c)*dmaqf_dso4f(ispa,:)*k1*k2*kco2*pco2x*prox**(ss_add-1d0) &
                                & )
                            df1dmaq(ispa,:) = df1dmaq(ispa,:) + ( & 
                                & + (base_charge(ispa)-1d0) &
                                &       *keqaq_c(ispa,ispa_c)*dmaqf_dmaq(ispa,:)*k1*k2*kco2*pco2x*prox**(ss_add-1d0) &
                                & )
                            df1dmgas(ipco2,:) = df1dmgas(ipco2,:) + ( & 
                                & + (base_charge(ispa)-1d0) &
                                &       *keqaq_c(ispa,ispa_c)*dmaqf_dpco2(ispa,:)*k1*k2*kco2*pco2x*prox**(ss_add-1d0) &
                                & + (base_charge(ispa)-1d0) &
                                &       *keqaq_c(ispa,ispa_c)*maqf_loc(ispa,:)*k1*k2*kco2*1d0*prox**(ss_add-1d0) &
                                & )
                            if (print_res) write(88,'(A11)', advance='no') trim(adjustl(chraq_all(ispa)))//'(hco3)'
                        endif 
                    endif 
                enddo 
                ! account for complexation with free SO4
                do ispa_s = 1,2
                    if ( keqaq_s(ispa,ispa_s) > 0d0) then 
                        rspa_s = real(ispa_s,kind=8)
                        f1 = f1 + (base_charge(ispa)-2d0*rspa_s)*keqaq_s(ispa,ispa_s)*maqf_loc(ispa,:)*so4f**rspa_s*prox**ss_add
                        df1 = df1 + ( & 
                            & + (base_charge(ispa)-2d0*rspa_s)*keqaq_s(ispa,ispa_s)*dmaqf_dpro(ispa,:)*so4f**rspa_s*prox**ss_add & 
                            & + (base_charge(ispa)-2d0*rspa_s) &
                            &       *keqaq_s(ispa,ispa_s)*maqf_loc(ispa,:)*so4f**rspa_s*ss_add*prox**(ss_add-1d0) & 
                            & )
                        df12 = df12 + ( & 
                            & + (base_charge(ispa)-2d0*rspa_s) &
                            &       *keqaq_s(ispa,ispa_s)*maqf_loc(ispa,:)*rspa_s*so4f**(rspa_s-1d0)*prox**ss_add & 
                            & + (base_charge(ispa)-2d0*rspa_s)*keqaq_s(ispa,ispa_s)*dmaqf_dso4f(ispa,:)*so4f**rspa_s*prox**ss_add & 
                            & )
                        df1dmaq(ispa,:) = df1dmaq(ispa,:) + ( & 
                            & + (base_charge(ispa)-2d0*rspa_s)*keqaq_s(ispa,ispa_s)*dmaqf_dmaq(ispa,:)*so4f**rspa_s*prox**ss_add & 
                            & )
                        df1dmgas(ipco2,:) = df1dmgas(ipco2,:) + ( & 
                            & + (base_charge(ispa)-2d0*rspa_s)*keqaq_s(ispa,ispa_s)*dmaqf_dpco2(ispa,:)*so4f**rspa_s*prox**ss_add & 
                            & )
                        if (print_res) then 
                            write(chrint,'(I1)') ispa_s
                            write(88,'(A11)', advance='no') trim(adjustl(chraq_all(ispa)))//'(so4)'//trim(adjustl(chrint))
                        endif 
                        ! ### SO4 mass balance
                        ! account for complexation with free SO4
                        f2 = f2 - rspa_s*keqaq_s(ispa,ispa_s)*maqf_loc(ispa,:)*so4f**rspa_s*prox**ss_add
                        df2 = df2 - ( &
                            & + rspa_s*keqaq_s(ispa,ispa_s)*maqf_loc(ispa,:)*rspa_s*so4f**(rspa_s-1d0)*prox**ss_add &
                            & + rspa_s*keqaq_s(ispa,ispa_s)*dmaqf_dso4f(ispa,:)*so4f**rspa_s*prox**ss_add &
                            & )
                        df21 = df21 - ( &
                            & + rspa_s*keqaq_s(ispa,ispa_s)*dmaqf_dpro(ispa,:)*so4f**rspa_s*prox**ss_add &
                            & + rspa_s*keqaq_s(ispa,ispa_s)*maqf_loc(ispa,:)*so4f**rspa_s*ss_add*prox**(ss_add-1d0) &
                            & )
                        df2dmaq(ispa,:) = df2dmaq(ispa,:) - ( &
                            & + rspa_s*keqaq_s(ispa,ispa_s)*dmaqf_dmaq(ispa,:)*so4f**rspa_s*prox**ss_add &
                            & )
                        df2dmgas(ipco2,:) = df2dmgas(ipco2,:) - ( &
                            & + rspa_s*keqaq_s(ispa,ispa_s)*dmaqf_dpco2(ispa,:)*so4f**rspa_s*prox**ss_add &
                            & )
                        !### SO4 mass balance ###
                            
                    endif 
                enddo 
                ! currently NO3 complexation with cations are ignored
            endif 
        enddo     

        
#ifdef debug 
        print *, 'v7_3'
        print *, iter
        print *, 'f1',f1
        print *
        print *, 'df1',df1
        print *
        print *, 'df12',df12
        print *
        print *, 'f2',f2
        print *
        print *, 'df2',df2
        print *
        print *, 'df21',df21
        print *
        print *, 'prox',prox
        print *
        print *, 'so4f',so4f
        print *
#endif 
        
        df1 = df1*prox
        df21 = df21*prox
        df2 = df2*so4f
        df12 = df12*so4f
        
        if (any(isnan(f1)).or.any(isnan(f2)).or.any(isnan(df1)).or.any(isnan(df2)) &
            & .or.any(isnan(df12)).or.any(isnan(df21))) then 
            print*,'found nan during the course of ph calc'
            print *,any(isnan(f1)),any(isnan(f2)),any(isnan(df1)),any(isnan(df2)) &
                & ,any(isnan(df12)),any(isnan(df21))
            print *,prox
            ph_error = .true.
            exit
            ! pause 
        endif 
        
        
        if (nmx/=nz) then 
            amx = 0d0
            ymx = 0d0
            
            ymx(1:nz) = f1(:)
            ymx(nz+1:nmx) = f2(:)
            
            do iz=1,nz
                amx(iz,iz)=df1(iz)
                amx(nz+iz,nz+iz)=df2(iz)
                amx(iz,nz+iz)=df12(iz)
                amx(nz+iz,iz)=df21(iz)
            enddo 
            ymx = -ymx
            
            call DGESV(nmx,int(1),amx,nmx,ipiv,ymx,nmx,info) 
            
            prox = prox*exp( ymx(1:nz) )
            so4f = so4f*exp( ymx(nz+1:nmx) )
            
            error = maxval(abs(exp( ymx )-1d0))
            if (isnan(error) .or. info/=0) then 
                error = 1d4
                ph_error = .true.
                exit 
            endif 
        else 
            prox = prox*exp( -f1/df1 )
            error = maxval(abs(exp( -f1/df1 )-1d0))
            if (isnan(error)) error = 1d4
        endif 
        
        iter = iter + 1
        
        if (iter > 3000) then 
            print *,'iteration exceeds 3000'
            ph_error = .true.
            return
        endif 
    enddo  
#ifdef timing
    call cpu_time( t2 )
    print *, "cpu time:", t2-t1, "seconds [v7_3] per ph & SO4f soultion."
#endif 
endif 

ph_iter = iter

if (any(isnan(prox)) .or. any(prox<=0d0)) then     
    print *, (-log10(prox(iz)),iz=1,nz,nz/5)
    print*,'ph is nan or <= zero'
    ph_error = .true.
    ! stop
endif 

call get_maqf_all( &
    & nz,nsp_aq_all,nsp_gas_all &
    & ,chraq_all,chrgas_all &
    & ,keqgas_h,keqaq_h,keqaq_c,keqaq_s,keqaq_no3 &
    & ,mgasx_loc,maqx_loc,prox,so4f &
    & ,dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2 &! output
    & ,maqf_loc  &! output
    & )

if (print_cb) print_res = .true.


if (print_res) write(88,'(A11)') 'tot_charge'

f1_chk = 0d0
ss_add = 0d0
if (print_res) then
    do iz = 1, nz
        f1_chk(iz) = f1_chk(iz) + prox(iz)**(ss_add+1d0) - kw*prox(iz)**(ss_add-1d0)
        write(88,'(3E11.3)', advance='no') z(iz),prox(iz), kw/prox(iz)

        ! adding charges coming from aq species in eq with gases
        ! pCO2
        f1_chk(iz) = f1_chk(iz)  -  k1*kco2*pco2x(iz)*prox(iz)**(ss_add-1d0)  -  2d0*k2*k1*kco2*pco2x(iz)*prox(iz)**(ss_add-2d0)
        write(88,'(2E11.3)', advance='no')    k1*kco2*pco2x(iz)/prox(iz),  k2*k1*kco2*pco2x(iz)/prox(iz)**2d0
        ! pNH3
        f1_chk(iz) = f1_chk(iz)  +  pnh3x(iz)*knh3/k1nh3*prox(iz)**(ss_add+1d0)
        write(88,'(E11.3)', advance='no')    pnh3x(iz)*knh3/k1nh3*prox(iz)

        do ispa = 1, nsp_aq_all
            
            f1_chk(iz) = f1_chk(iz) + base_charge(ispa)*maqf_loc(ispa,iz)*prox(iz)**(ss_add)
            write(88,'(E11.3)', advance='no') maqf_loc(ispa,iz) 
            
            ! annions
            if (trim(adjustl(chraq_all(ispa)))=='no3' .or. trim(adjustl(chraq_all(ispa)))=='so4') then 
                
                ! account for speces associated with H+
                do ispa_h = 1,4
                    if ( keqaq_h(ispa,ispa_h) > 0d0) then 
                        rspa_h = real(ispa_h,kind=8)
                        f1_chk(iz) = f1_chk(iz) &
                            & + (base_charge(ispa) + rspa_h)*keqaq_h(ispa,ispa_h)*maqf_loc(ispa,iz)*prox(iz)**(rspa_h+ss_add)
                        write(88,'(E11.3)', advance='no') keqaq_h(ispa,ispa_h)*maqf_loc(ispa,iz)*prox(iz)**rspa_h
                    endif 
                enddo 
            ! cations
            else 
                ! account for hydrolysis speces
                do ispa_h = 1,4
                    if ( keqaq_h(ispa,ispa_h) > 0d0) then 
                        rspa_h = real(ispa_h,kind=8)
                        f1_chk(iz) = f1_chk(iz) &
                            & + (base_charge(ispa) - rspa_h)*keqaq_h(ispa,ispa_h)*maqf_loc(ispa,iz)*prox(iz)**(ss_add-rspa_h)
                        write(88,'(E11.3)', advance='no') keqaq_h(ispa,ispa_h)*maqf_loc(ispa,iz)/prox(iz)**rspa_h
                    endif 
                enddo 
                ! account for species associated with CO3-- (ispa_c =1) and HCO3- (ispa_c =2)
                do ispa_c = 1,2
                    if ( keqaq_c(ispa,ispa_c) > 0d0) then 
                        if (ispa_c == 1) then ! with CO3--
                            f1_chk(iz) = f1_chk(iz) + (base_charge(ispa)-2d0) &
                                & *keqaq_c(ispa,ispa_c)*maqf_loc(ispa,iz)*k1*k2*kco2*pco2x(iz)*prox(iz)**(ss_add-2d0)
                            write(88,'(E11.3)', advance='no') &
                                & keqaq_c(ispa,ispa_c)*maqf_loc(ispa,iz)*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0
                        elseif (ispa_c == 2) then ! with HCO3-
                            f1_chk(iz) = f1_chk(iz) + (base_charge(ispa)-1d0) &
                                & *keqaq_c(ispa,ispa_c)*maqf_loc(ispa,iz)*k1*k2*kco2*pco2x(iz)*prox(iz)**(ss_add-1d0)
                            write(88,'(E11.3)', advance='no') &
                                & keqaq_c(ispa,ispa_c)*maqf_loc(ispa,iz)*k1*k2*kco2*pco2x(iz)/prox(iz)
                        endif 
                    endif 
                enddo 
                ! account for complexation with free SO4
                do ispa_s = 1,2
                    if ( keqaq_s(ispa,ispa_s) > 0d0) then 
                        rspa_s = real(ispa_s,kind=8)
                        f1_chk(iz) = f1_chk(iz)  + (base_charge(ispa)-2d0*rspa_s) &
                            & *keqaq_s(ispa,ispa_s)*maqf_loc(ispa,iz)*so4f(iz)**rspa_s*prox(iz)**ss_add
                        write(88,'(E11.3)', advance='no') keqaq_s(ispa,ispa_s)*maqf_loc(ispa,iz)*so4f(iz)**rspa_s
                    endif 
                enddo 
                ! currently NO3 complexation with cations is ignored
            endif 
        enddo     
        write(88,'(E11.3)') f1_chk(iz)
    enddo 
endif 

if (print_res) close(88)


call calc_charge( &
    & nz,nsp_aq_all,nsp_gas_all &
    & ,chraq_all,chrgas_all &
    & ,kw,keqgas_h,keqaq_h,keqaq_c,keqaq_s  &
    & ,mgasx_loc,maqf_loc &
    & ,dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2 &
    & ,z,prox,so4f &
    & ,print_loc,print_res,ph_add_order &
    & ,df1,df12,df1dmaq,df1dmgas &!output
    & ,f1 &! output
    & )

    
call calc_so4_balance( &
    & nz,nsp_aq_all,nsp_gas_all &
    & ,chraq_all,chrgas_all &
    & ,keqaq_h,keqaq_s  &
    & ,maqf_loc &
    & ,dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2 &
    & ,prox,so4f,so4x &
    & ,ph_add_order &
    & ,df2,df21,df2dmaq,df2dmgas &! output
    & ,f2 &! output
    & )    

! call calc_charge_so4_balance( &
    ! & nz,nsp_aq_all,nsp_gas_all &
    ! & ,chraq_all,chrgas_all &
    ! & ,kw,keqgas_h,keqaq_h,keqaq_c,keqaq_s  &
    ! & ,base_charge &
    ! & ,mgasx_loc,maqf_loc &
    ! & ,dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2 &
    ! & ,z,prox,so4f,so4x &
    ! & ,print_loc,print_res,ph_add_order &
    ! & ,f1,df1,df12,df1dmaq,df1dmgas &!output
    ! & ,f2,df2,df21,df2dmaq,df2dmgas &!output
    ! & )    
    
do ispa=1,nsp_aq_all
    dmaq = 0d0
    dmaq(ispa,:) = dconc!*maqx_loc(ispa,:)
    call get_maqf_all( &
        & nz,nsp_aq_all,nsp_gas_all &
        & ,chraq_all,chrgas_all &
        & ,keqgas_h,keqaq_h,keqaq_c,keqaq_s,keqaq_no3 &
        & ,mgasx_loc,maqx_loc+dmaq,prox,so4f &
        & ,dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2 &! output
        & ,maqf_loc  &! output
        & )
        
    call calc_charge( &
        & nz,nsp_aq_all,nsp_gas_all &
        & ,chraq_all,chrgas_all &
        & ,kw,keqgas_h,keqaq_h,keqaq_c,keqaq_s  &
        & ,mgasx_loc,maqf_loc &
        & ,dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2 &
        & ,z,prox,so4f &
        & ,print_loc,print_res,ph_add_order &
        & ,df1_dum,df12_dum,df1dmaq_dum,df1dmgas_dum &!output
        & ,f1_dum &! output
        & )
    
    call calc_so4_balance( &
        & nz,nsp_aq_all,nsp_gas_all &
        & ,chraq_all,chrgas_all &
        & ,keqaq_h,keqaq_s  &
        & ,maqf_loc &
        & ,dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2 &
        & ,prox,so4f,so4x &
        & ,ph_add_order &
        & ,df2_dum,df21_dum,df2dmaq_dum,df2dmgas_dum &! output
        & ,f2_dum &! output
        & )   
    dprodmaq_all(ispa,:) = -f1_dum/df1_dum/dconc!/maqx_loc(ispa,:) 
    dso4fdmaq_all(ispa,:) = -f2_dum/df2_dum/dconc!/maqx_loc(ispa,:) 
enddo 
    
do ispg=1,nsp_gas_all
    dmgas = 0d0
    dmgas(ispg,:) = dconc!*mgasx_loc(ispg,:)
    call get_maqf_all( &
        & nz,nsp_aq_all,nsp_gas_all &
        & ,chraq_all,chrgas_all &
        & ,keqgas_h,keqaq_h,keqaq_c,keqaq_s,keqaq_no3 &
        & ,mgasx_loc+dmgas,maqx_loc,prox,so4f &
        & ,dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2 &! output
        & ,maqf_loc  &! output
        & )
        
    call calc_charge( &
        & nz,nsp_aq_all,nsp_gas_all &
        & ,chraq_all,chrgas_all &
        & ,kw,keqgas_h,keqaq_h,keqaq_c,keqaq_s  &
        & ,mgasx_loc+dmgas,maqf_loc &
        & ,dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2 &
        & ,z,prox,so4f &
        & ,print_loc,print_res,ph_add_order &
        & ,df1_dum,df12_dum,df1dmaq_dum,df1dmgas_dum &!output
        & ,f1_dum &! output
        & )
    
    call calc_so4_balance( &
        & nz,nsp_aq_all,nsp_gas_all &
        & ,chraq_all,chrgas_all &
        & ,keqaq_h,keqaq_s  &
        & ,maqf_loc &
        & ,dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2 &
        & ,prox,so4f,so4x &
        & ,ph_add_order &
        & ,df2_dum,df21_dum,df2dmaq_dum,df2dmgas_dum &! output
        & ,f2_dum &! output
        & )   
    dprodmgas_all(ispg,:) = -f1_dum/df1_dum/dconc!/mgasx_loc(ispg,:)  
    dso4fdmgas_all(ispg,:) = -f2_dum/df2_dum/dconc !/mgasx_loc(ispg,:)
enddo 
#ifdef test_anal
do ispa = 1, nsp_aq_all
    dprodmaq_all(ispa,:) = - df1dmaq(ispa,:)/df1 !+ df2dmaq(ispa,:)/df21 
    dso4fdmaq_all(ispa,:) = - df2dmaq(ispa,:)/df2 ! + df1dmaq(ispa,:)/df12
enddo 

do ispg = 1, nsp_gas_all
    dprodmgas_all(ispg,:) = - df1dmgas(ispg,:)/df1 !+ df2dmgas(ispg,:)/df21
    dso4fdmgas_all(ispg,:) = -df2dmgas(ispg,:)/df2 !+ df1dmgas(ispg,:)/df12
    ! dso4fdmgas_all(ispg,:) = - df1dmgas(ispg,:)/df12
#ifdef phiter2_chk
    if (chrgas_all(ispg)=='pco2') then 
        print*,'df1dmgas',df1dmgas(ispg,:)
        print*
        print*,'df2dmgas',df2dmgas(ispg,:)
        print*
        print*,'df1',df1
        print*
        print*,'df12',df12
        print*
        print*,'df2',df2
        print*
        print*,'df21',df21
        print*
    endif 
#endif 
    ! if (chrgas_all(ispg)=='pco2') then 
        ! print *,'df1dmgas(ispg,:)/df1'
        ! print *,df1dmgas(ispg,:)/df1
        ! print * 
        ! print *,'df2dmgas(ispg,:)/df21'
        ! print *,df2dmgas(ispg,:)/df21
        ! print * 
        ! print *,'dprodmgas_all(ispg,:)'
        ! print *,dprodmgas_all(ispg,:)
        ! print *  
        ! print *, '------------'  
        ! print *  
        ! print *,'df2dmgas(ispg,:)/df2'
        ! print *,df2dmgas(ispg,:)/df2
        ! print * 
        ! print *,'df1dmgas(ispg,:)/df12'
        ! print *,df1dmgas(ispg,:)/df12
        ! print * 
        ! print *,'dso4fdmgas_all(ispg,:)'
        ! print *,dso4fdmgas_all(ispg,:)
        ! print * 
    ! endif 
enddo 
#endif 

endsubroutine calc_pH_v7_4

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine calc_charge_so4_balance( &
    & nz,nsp_aq_all,nsp_gas_all &
    & ,chraq_all,chrgas_all &
    & ,kw,keqgas_h,keqaq_h,keqaq_c,keqaq_s  &
    & ,base_charge &
    & ,mgasx_loc,maqf_loc &
    & ,dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2 &
    & ,z,prox,so4f,so4x &
    & ,print_loc,print_res,ph_add_order &
    & ,f1,df1,df12,df1dmaq,df1dmgas &!output
    & ,f2,df2,df21,df2dmaq,df2dmgas &!output
    & )
implicit none

integer,intent(in)::nz,nsp_aq_all,nsp_gas_all
character(5),dimension(nsp_aq_all)::chraq_all
character(5),dimension(nsp_gas_all)::chrgas_all
real(kind=8),intent(in)::kw,ph_add_order
real(kind=8),dimension(nsp_gas_all,3),intent(in)::keqgas_h
real(kind=8),dimension(nsp_aq_all,4),intent(in)::keqaq_h
real(kind=8),dimension(nsp_aq_all,2),intent(in)::keqaq_c,keqaq_s
real(kind=8),dimension(nsp_gas_all,nz),intent(in)::mgasx_loc
real(kind=8),dimension(nsp_aq_all,nz),intent(in)::maqf_loc
real(kind=8),dimension(nsp_aq_all,nz),intent(in)::dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2
real(kind=8),dimension(nsp_aq_all),intent(in)::base_charge
real(kind=8),dimension(nz),intent(in)::z,prox,so4f,so4x
real(kind=8),dimension(nz),intent(out)::f1,df1,df12,f2,df2,df21
real(kind=8),dimension(nsp_aq_all,nz),intent(out)::df1dmaq,df2dmaq
real(kind=8),dimension(nsp_gas_all,nz),intent(out)::df1dmgas,df2dmgas

logical,intent(in)::print_res
character(500),intent(in)::print_loc

integer ieqgas_h0,ieqgas_h1,ieqgas_h2
data ieqgas_h0,ieqgas_h1,ieqgas_h2/1,2,3/

integer ispa,ispa_h,ispa_c,ispa_s,iz,ipco2,ipnh3

real(kind=8) kco2,k1,k2,knh3,k1nh3,rspa_h,rspa_s,ss_add
real(kind=8),dimension(nz)::pco2x,pnh3x
real(kind=8),dimension(nz)::f1_chk

character(1) chrint


if (print_res) open(88,file = trim(adjustl(print_loc)),status='replace')

ipco2 = findloc(chrgas_all,'pco2',dim=1)
ipnh3 = findloc(chrgas_all,'pnh3',dim=1)

kco2 = keqgas_h(ipco2,ieqgas_h0)
k1 = keqgas_h(ipco2,ieqgas_h1)
k2 = keqgas_h(ipco2,ieqgas_h2)

pco2x = mgasx_loc(ipco2,:)


knh3 = keqgas_h(ipnh3,ieqgas_h0)
k1nh3 = keqgas_h(ipnh3,ieqgas_h1)

pnh3x = mgasx_loc(ipnh3,:)

ss_add = ph_add_order

f1 = 0d0
df1 = 0d0
df12 = 0d0
df1dmaq = 0d0
df1dmgas = 0d0

f1 = f1 + prox**(ss_add+1d0) - kw*prox**(ss_add-1d0)
df1 = df1 + (ss_add+1d0)*prox**ss_add - kw*(ss_add-1d0)*prox**(ss_add-2d0)
if (print_res) write(88,'(3A11)', advance='no') 'z','h', 'oh'

! adding charges coming from aq species in eq with gases
! pCO2
f1 = f1  -  k1*kco2*pco2x*prox**(ss_add-1d0)  -  2d0*k2*k1*kco2*pco2x*prox**(ss_add-2d0)
df1 = df1  -  k1*kco2*pco2x*(ss_add-1d0)*prox**(ss_add-2d0)  -  2d0*k2*k1*kco2*pco2x*(ss_add-2d0)*prox**(ss_add-3d0)
df1dmgas(ipco2,:) = df1dmgas(ipco2,:) -  k1*kco2*1d0*prox**(ss_add-1d0)  -  2d0*k2*k1*kco2*1d0*prox**(ss_add-2d0)
if (print_res) write(88,'(2A11)', advance='no') 'hco3','co3'
! pNH3
f1 = f1  +  pnh3x*knh3/k1nh3*prox**(ss_add+1d0)
df1 = df1  +  pnh3x*knh3/k1nh3*(ss_add+1d0)*prox**ss_add
df1dmgas(ipnh3,:) = df1dmgas(ipnh3,:)  +  1d0*knh3/k1nh3*prox**(ss_add+1d0)
if (print_res) write(88,'(A11)', advance='no') 'nh4'

!### SO4 mass balance ###
f2 = 0d0
df2 = 0d0
df21 = 0d0
df2dmaq = 0d0
df2dmgas = 0d0

f2 = so4x*prox**ss_add - so4f*prox**ss_add
df2 = - 1d0*prox**ss_add
df21 = so4x*ss_add*prox**(ss_add-1d0) - so4f*ss_add*prox**(ss_add-1d0)
df2dmaq(findloc(chraq_all,'so4',dim=1),:) =  1d0*prox**ss_add 
!### SO4 mass balance ###

do ispa = 1, nsp_aq_all
    
    f1 = f1 + base_charge(ispa)*maqf_loc(ispa,:)*prox**(ss_add)
    df1 = df1 + ( &
        & + base_charge(ispa)*dmaqf_dpro(ispa,:)*prox**(ss_add)  &
        & + base_charge(ispa)*maqf_loc(ispa,:)*(ss_add)*prox**(ss_add-1d0)  &
        & )
    df12 = df12 + base_charge(ispa)*dmaqf_dso4f(ispa,:)*prox**(ss_add) 
    df1dmaq(ispa,:) = df1dmaq(ispa,:) + base_charge(ispa)*dmaqf_dmaq(ispa,:)*prox**(ss_add) 
    df1dmgas(ipco2,:) = df1dmgas(ipco2,:) + base_charge(ispa)*dmaqf_dpco2(ispa,:) *prox**(ss_add)
    if (print_res) write(88,'(A11)', advance='no') trim(adjustl(chraq_all(ispa)))
    
    ! annions
    if (trim(adjustl(chraq_all(ispa)))=='no3' .or. trim(adjustl(chraq_all(ispa)))=='so4') then 
        
        ! account for speces associated with H+
        do ispa_h = 1,4
            if ( keqaq_h(ispa,ispa_h) > 0d0) then 
                rspa_h = real(ispa_h,kind=8)
                f1 = f1 + (base_charge(ispa) + rspa_h)*keqaq_h(ispa,ispa_h)*maqf_loc(ispa,:)*prox**(rspa_h+ss_add)
                df1 = df1 + ( & 
                    & + (base_charge(ispa) + rspa_h) &
                    &        *keqaq_h(ispa,ispa_h)*maqf_loc(ispa,:)*(rspa_h+ss_add)*prox**(rspa_h+ss_add-1d0) &
                    & + (base_charge(ispa) + rspa_h)*keqaq_h(ispa,ispa_h)*dmaqf_dpro(ispa,:)*prox**(rspa_h+ss_add) &
                    & )
                df12 = df12 + (& 
                    & + (base_charge(ispa) + rspa_h)*keqaq_h(ispa,ispa_h)*dmaqf_dso4f(ispa,:)*prox**(rspa_h+ss_add) &
                    & )
                df1dmaq(ispa,:) = df1dmaq(ispa,:) + (& 
                    & + (base_charge(ispa) + rspa_h)*keqaq_h(ispa,ispa_h)*dmaqf_dmaq(ispa,:)*prox**(rspa_h+ss_add) &
                    & )
                df1dmgas(ipco2,:) = df1dmgas(ipco2,:) + (& 
                    & + (base_charge(ispa) + rspa_h)*keqaq_h(ispa,ispa_h)*dmaqf_dpco2(ispa,:)*prox**(rspa_h+ss_add) &
                    & )
                if (print_res) then 
                    write(chrint,'(I1)') ispa_h
                    write(88,'(A11)', advance='no') 'h'//trim(adjustl(chrint))//trim(adjustl(chraq_all(ispa)))
                endif 
                
                ! ### SO4 mass balance
                ! account for SO4 association with H+
                if ( trim(adjustl(chraq_all(ispa)))=='so4') then 
                    f2 = f2 - keqaq_h(ispa,ispa_h)*so4f*prox**(rspa_h+ss_add)
                    df2 = df2 - keqaq_h(ispa,ispa_h)*1d0*prox**(rspa_h+ss_add)
                    df21 = df21 - keqaq_h(ispa,ispa_h)*so4f*(rspa_h+ss_add)*prox**(rspa_h+ss_add-1d0)
                endif 
                !### SO4 mass balance ###
                
            endif 
        enddo 
    ! cations
    else 
        ! account for hydrolysis speces
        do ispa_h = 1,4
            if ( keqaq_h(ispa,ispa_h) > 0d0) then 
                rspa_h = real(ispa_h,kind=8)
                f1 = f1 + (base_charge(ispa) - rspa_h)*keqaq_h(ispa,ispa_h)*maqf_loc(ispa,:)*prox**(ss_add-rspa_h)
                df1 = df1 + ( &
                    & + (base_charge(ispa) - rspa_h) &
                    &       *keqaq_h(ispa,ispa_h)*maqf_loc(ispa,:)*(ss_add-rspa_h)*prox**(ss_add-rspa_h-1d0) &
                    & + (base_charge(ispa) - rspa_h)*keqaq_h(ispa,ispa_h)*dmaqf_dpro(ispa,:)*prox**(ss_add-rspa_h) &
                    & )
                df12 = df12 + ( &
                    & + (base_charge(ispa) - rspa_h)*keqaq_h(ispa,ispa_h)*dmaqf_dso4f(ispa,:)*prox**(ss_add-rspa_h) &
                    & )
                df1dmaq(ispa,:) = df1dmaq(ispa,:) + ( &
                    & + (base_charge(ispa) - rspa_h)*keqaq_h(ispa,ispa_h)*dmaqf_dmaq(ispa,:)*prox**(ss_add-rspa_h) &
                    & )
                df1dmgas(ipco2,:) = df1dmgas(ipco2,:) + ( &
                    & + (base_charge(ispa) - rspa_h)*keqaq_h(ispa,ispa_h)*dmaqf_dpco2(ispa,:)*prox**(ss_add-rspa_h) &
                    & )
                if (print_res) then 
                    write(chrint,'(I1)') ispa_h
                    write(88,'(A11)', advance='no') trim(adjustl(chraq_all(ispa)))//'(oh)'//trim(adjustl(chrint))
                endif 
            endif 
        enddo 
        ! account for species associated with CO3-- (ispa_c =1) and HCO3- (ispa_c =2)
        do ispa_c = 1,2
            if ( keqaq_c(ispa,ispa_c) > 0d0) then 
                if (ispa_c == 1) then ! with CO3--
                    f1 = f1 + (base_charge(ispa)-2d0)*keqaq_c(ispa,ispa_c)*maqf_loc(ispa,:)*k1*k2*kco2*pco2x*prox**(ss_add-2d0)
                    df1 = df1 + ( & 
                        & + (base_charge(ispa)-2d0) &
                        &       *keqaq_c(ispa,ispa_c)*maqf_loc(ispa,:)*k1*k2*kco2*pco2x*(ss_add-2d0)*prox**(ss_add-3d0) &
                        & + (base_charge(ispa)-2d0)*keqaq_c(ispa,ispa_c)*dmaqf_dpro(ispa,:)*k1*k2*kco2*pco2x*prox**(ss_add-2d0) &
                        & )
                    df12 = df12 + ( & 
                        & + (base_charge(ispa)-2d0)*keqaq_c(ispa,ispa_c)*dmaqf_dso4f(ispa,:)*k1*k2*kco2*pco2x*prox**(ss_add-2d0) &
                        & )
                    df1dmaq(ispa,:) = df1dmaq(ispa,:) + ( & 
                        & + (base_charge(ispa)-2d0)*keqaq_c(ispa,ispa_c)*dmaqf_dmaq(ispa,:)*k1*k2*kco2*pco2x*prox**(ss_add-2d0) &
                        & )
                    df1dmgas(ipco2,:) = df1dmgas(ipco2,:) + ( & 
                        & + (base_charge(ispa)-2d0)*keqaq_c(ispa,ispa_c)*dmaqf_dpco2(ispa,:)*k1*k2*kco2*pco2x*prox**(ss_add-2d0) &
                        & + (base_charge(ispa)-2d0)*keqaq_c(ispa,ispa_c)*maqf_loc(ispa,:)*k1*k2*kco2*1d0*prox**(ss_add-2d0) &
                        & )
                    if (print_res) write(88,'(A11)', advance='no') trim(adjustl(chraq_all(ispa)))//'(co3)'
                elseif (ispa_c == 2) then ! with HCO3-
                    f1 = f1 + (base_charge(ispa)-1d0)*keqaq_c(ispa,ispa_c)*maqf_loc(ispa,:)*k1*k2*kco2*pco2x*prox**(ss_add-1d0)
                    df1 = df1 + ( & 
                        & + (base_charge(ispa)-1d0) &
                        &       *keqaq_c(ispa,ispa_c)*maqf_loc(ispa,:)*k1*k2*kco2*pco2x*(ss_add-1d0)*prox**(ss_add-2d0) &
                        & + (base_charge(ispa)-1d0)*keqaq_c(ispa,ispa_c)*dmaqf_dpro(ispa,:)*k1*k2*kco2*pco2x*prox**(ss_add-1d0) &
                        & )
                    df12 = df12 + ( & 
                        & + (base_charge(ispa)-1d0)*keqaq_c(ispa,ispa_c)*dmaqf_dso4f(ispa,:)*k1*k2*kco2*pco2x*prox**(ss_add-1d0) &
                        & )
                    df1dmaq(ispa,:) = df1dmaq(ispa,:) + ( & 
                        & + (base_charge(ispa)-1d0)*keqaq_c(ispa,ispa_c)*dmaqf_dmaq(ispa,:)*k1*k2*kco2*pco2x*prox**(ss_add-1d0) &
                        & )
                    df1dmgas(ipco2,:) = df1dmgas(ipco2,:) + ( & 
                        & + (base_charge(ispa)-1d0)*keqaq_c(ispa,ispa_c)*dmaqf_dpco2(ispa,:)*k1*k2*kco2*pco2x*prox**(ss_add-1d0) &
                        & + (base_charge(ispa)-1d0)*keqaq_c(ispa,ispa_c)*maqf_loc(ispa,:)*k1*k2*kco2*1d0*prox**(ss_add-1d0) &
                        & )
                    if (print_res) write(88,'(A11)', advance='no') trim(adjustl(chraq_all(ispa)))//'(hco3)'
                endif 
            endif 
        enddo 
        ! account for complexation with free SO4
        do ispa_s = 1,2
            if ( keqaq_s(ispa,ispa_s) > 0d0) then 
                rspa_s = real(ispa_s,kind=8)
                f1 = f1 + (base_charge(ispa)-2d0*rspa_s)*keqaq_s(ispa,ispa_s)*maqf_loc(ispa,:)*so4f**rspa_s*prox**ss_add
                df1 = df1 + ( & 
                    & + (base_charge(ispa)-2d0*rspa_s)*keqaq_s(ispa,ispa_s)*dmaqf_dpro(ispa,:)*so4f**rspa_s*prox**ss_add & 
                    & + (base_charge(ispa)-2d0*rspa_s) &
                    &       *keqaq_s(ispa,ispa_s)*maqf_loc(ispa,:)*so4f**rspa_s*ss_add*prox**(ss_add-1d0) & 
                    & )
                df12 = df12 + ( & 
                    & + (base_charge(ispa)-2d0*rspa_s) &
                    &       *keqaq_s(ispa,ispa_s)*maqf_loc(ispa,:)*rspa_s*so4f**(rspa_s-1d0)*prox**ss_add & 
                    & + (base_charge(ispa)-2d0*rspa_s)*keqaq_s(ispa,ispa_s)*dmaqf_dso4f(ispa,:)*so4f**rspa_s*prox**ss_add & 
                    & )
                df1dmaq(ispa,:) = df1dmaq(ispa,:) + ( & 
                    & + (base_charge(ispa)-2d0*rspa_s)*keqaq_s(ispa,ispa_s)*dmaqf_dmaq(ispa,:)*so4f**rspa_s*prox**ss_add & 
                    & )
                df1dmgas(ipco2,:) = df1dmgas(ipco2,:) + ( & 
                    & + (base_charge(ispa)-2d0*rspa_s)*keqaq_s(ispa,ispa_s)*dmaqf_dpco2(ispa,:)*so4f**rspa_s*prox**ss_add & 
                    & )
                if (print_res) then 
                    write(chrint,'(I1)') ispa_s
                    write(88,'(A11)', advance='no') trim(adjustl(chraq_all(ispa)))//'(so4)'//trim(adjustl(chrint))
                endif 
                ! ### SO4 mass balance
                ! account for complexation with free SO4
                f2 = f2 - rspa_s*keqaq_s(ispa,ispa_s)*maqf_loc(ispa,:)*so4f**rspa_s*prox**ss_add
                df2 = df2 - ( &
                    & + rspa_s*keqaq_s(ispa,ispa_s)*maqf_loc(ispa,:)*rspa_s*so4f**(rspa_s-1d0)*prox**ss_add &
                    & + rspa_s*keqaq_s(ispa,ispa_s)*dmaqf_dso4f(ispa,:)*so4f**rspa_s*prox**ss_add &
                    & )
                df21 = df21 - ( &
                    & + rspa_s*keqaq_s(ispa,ispa_s)*dmaqf_dpro(ispa,:)*so4f**rspa_s*prox**ss_add &
                    & + rspa_s*keqaq_s(ispa,ispa_s)*maqf_loc(ispa,:)*so4f**rspa_s*ss_add*prox**(ss_add-1d0) &
                    & )
                df2dmaq(ispa,:) = df2dmaq(ispa,:) - ( &
                    & + rspa_s*keqaq_s(ispa,ispa_s)*dmaqf_dmaq(ispa,:)*so4f**rspa_s*prox**ss_add &
                    & )
                df2dmgas(ipco2,:) = df2dmgas(ipco2,:) - ( &
                    & + rspa_s*keqaq_s(ispa,ispa_s)*dmaqf_dpco2(ispa,:)*so4f**rspa_s*prox**ss_add &
                    & )
                !### SO4 mass balance ###
                    
            endif 
        enddo 
        ! currently NO3 complexation with cations are ignored
    endif 
enddo     

if (print_res) write(88,'(A11)') 'tot_charge'

f1_chk = 0d0
ss_add = 0d0
if (print_res) then
    do iz = 1, nz
        f1_chk(iz) = f1_chk(iz) + prox(iz)**(ss_add+1d0) - kw*prox(iz)**(ss_add-1d0)
        write(88,'(3E11.3)', advance='no') z(iz),prox(iz), kw/prox(iz)

        ! adding charges coming from aq species in eq with gases
        ! pCO2
        f1_chk(iz) = f1_chk(iz)  -  k1*kco2*pco2x(iz)*prox(iz)**(ss_add-1d0)  -  2d0*k2*k1*kco2*pco2x(iz)*prox(iz)**(ss_add-2d0)
        write(88,'(2E11.3)', advance='no')    k1*kco2*pco2x(iz)/prox(iz),  k2*k1*kco2*pco2x(iz)/prox(iz)**2d0
        ! pNH3
        f1_chk(iz) = f1_chk(iz)  +  pnh3x(iz)*knh3/k1nh3*prox(iz)**(ss_add+1d0)
        write(88,'(E11.3)', advance='no')    pnh3x(iz)*knh3/k1nh3*prox(iz)

        do ispa = 1, nsp_aq_all
            
            f1_chk(iz) = f1_chk(iz) + base_charge(ispa)*maqf_loc(ispa,iz)*prox(iz)**(ss_add)
            write(88,'(E11.3)', advance='no') maqf_loc(ispa,iz) 
            
            ! annions
            if (trim(adjustl(chraq_all(ispa)))=='no3' .or. trim(adjustl(chraq_all(ispa)))=='so4') then 
                
                ! account for speces associated with H+
                do ispa_h = 1,4
                    if ( keqaq_h(ispa,ispa_h) > 0d0) then 
                        rspa_h = real(ispa_h,kind=8)
                        f1_chk(iz) = f1_chk(iz) &
                            & + (base_charge(ispa) + rspa_h)*keqaq_h(ispa,ispa_h)*maqf_loc(ispa,iz)*prox(iz)**(rspa_h+ss_add)
                        write(88,'(E11.3)', advance='no') keqaq_h(ispa,ispa_h)*maqf_loc(ispa,iz)*prox(iz)**rspa_h
                    endif 
                enddo 
            ! cations
            else 
                ! account for hydrolysis speces
                do ispa_h = 1,4
                    if ( keqaq_h(ispa,ispa_h) > 0d0) then 
                        rspa_h = real(ispa_h,kind=8)
                        f1_chk(iz) = f1_chk(iz) &
                            & + (base_charge(ispa) - rspa_h)*keqaq_h(ispa,ispa_h)*maqf_loc(ispa,iz)*prox(iz)**(ss_add-rspa_h)
                        write(88,'(E11.3)', advance='no') keqaq_h(ispa,ispa_h)*maqf_loc(ispa,iz)/prox(iz)**rspa_h
                    endif 
                enddo 
                ! account for species associated with CO3-- (ispa_c =1) and HCO3- (ispa_c =2)
                do ispa_c = 1,2
                    if ( keqaq_c(ispa,ispa_c) > 0d0) then 
                        if (ispa_c == 1) then ! with CO3--
                            f1_chk(iz) = f1_chk(iz) + (base_charge(ispa)-2d0) &
                                & *keqaq_c(ispa,ispa_c)*maqf_loc(ispa,iz)*k1*k2*kco2*pco2x(iz)*prox(iz)**(ss_add-2d0)
                            write(88,'(E11.3)', advance='no') &
                                & keqaq_c(ispa,ispa_c)*maqf_loc(ispa,iz)*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0
                        elseif (ispa_c == 2) then ! with HCO3-
                            f1_chk(iz) = f1_chk(iz) + (base_charge(ispa)-1d0) &
                                & *keqaq_c(ispa,ispa_c)*maqf_loc(ispa,iz)*k1*k2*kco2*pco2x(iz)*prox(iz)**(ss_add-1d0)
                            write(88,'(E11.3)', advance='no') &
                                & keqaq_c(ispa,ispa_c)*maqf_loc(ispa,iz)*k1*k2*kco2*pco2x(iz)/prox(iz)
                        endif 
                    endif 
                enddo 
                ! account for complexation with free SO4
                do ispa_s = 1,2
                    if ( keqaq_s(ispa,ispa_s) > 0d0) then 
                        rspa_s = real(ispa_s,kind=8)
                        f1_chk(iz) = f1_chk(iz)  + (base_charge(ispa)-2d0*rspa_s) &
                            & *keqaq_s(ispa,ispa_s)*maqf_loc(ispa,iz)*so4f(iz)**rspa_s*prox(iz)**ss_add
                        write(88,'(E11.3)', advance='no') keqaq_s(ispa,ispa_s)*maqf_loc(ispa,iz)*so4f(iz)**rspa_s
                    endif 
                enddo 
                ! currently NO3 complexation with cations is ignored
            endif 
        enddo     
        write(88,'(E11.3)') f1_chk(iz)
    enddo 
endif 

if (print_res) close(88)

endsubroutine calc_charge_so4_balance

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine calc_charge( &
    & nz,nsp_aq_all,nsp_gas_all &
    & ,chraq_all,chrgas_all &
    & ,kw,keqgas_h,keqaq_h,keqaq_c,keqaq_s  &
    & ,mgasx_loc,maqf_loc &
    & ,dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2 &
    & ,z,prox,so4f &
    & ,print_loc,print_res,ph_add_order &
    & ,df1,df12,df1dmaq,df1dmgas &!output
    & ,f1 &! output
    & )
implicit none

integer,intent(in)::nz,nsp_aq_all,nsp_gas_all
character(5),dimension(nsp_aq_all)::chraq_all
character(5),dimension(nsp_gas_all)::chrgas_all
real(kind=8),intent(in)::kw,ph_add_order
real(kind=8),dimension(nsp_gas_all,3),intent(in)::keqgas_h
real(kind=8),dimension(nsp_aq_all,4),intent(in)::keqaq_h
real(kind=8),dimension(nsp_aq_all,2),intent(in)::keqaq_c,keqaq_s
real(kind=8),dimension(nsp_gas_all,nz),intent(in)::mgasx_loc
real(kind=8),dimension(nsp_aq_all,nz),intent(in)::maqf_loc
real(kind=8),dimension(nsp_aq_all,nz),intent(in)::dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2
real(kind=8),dimension(nz),intent(in)::z,prox,so4f
real(kind=8),dimension(nz),intent(out)::f1,df1,df12
real(kind=8),dimension(nsp_aq_all,nz),intent(out)::df1dmaq
real(kind=8),dimension(nsp_gas_all,nz),intent(out)::df1dmgas

logical,intent(in)::print_res
character(500),intent(in)::print_loc

integer ieqgas_h0,ieqgas_h1,ieqgas_h2
data ieqgas_h0,ieqgas_h1,ieqgas_h2/1,2,3/

integer ispa,ispa_h,ispa_c,ispa_s,iz,ipco2,ipnh3

real(kind=8) kco2,k1,k2,knh3,k1nh3,rspa_h,rspa_s,ss_add
real(kind=8),dimension(nz)::pco2x,pnh3x
real(kind=8),dimension(nz)::f1_chk
real(kind=8),dimension(nsp_aq_all)::base_charge

character(1) chrint


if (print_res) open(88,file = trim(adjustl(print_loc)),status='replace')

ipco2 = findloc(chrgas_all,'pco2',dim=1)
ipnh3 = findloc(chrgas_all,'pnh3',dim=1)

kco2 = keqgas_h(ipco2,ieqgas_h0)
k1 = keqgas_h(ipco2,ieqgas_h1)
k2 = keqgas_h(ipco2,ieqgas_h2)

pco2x = mgasx_loc(ipco2,:)


knh3 = keqgas_h(ipnh3,ieqgas_h0)
k1nh3 = keqgas_h(ipnh3,ieqgas_h1)

pnh3x = mgasx_loc(ipnh3,:)

ss_add = ph_add_order

base_charge = 0d0

do ispa = 1, nsp_aq_all
    selectcase(trim(adjustl(chraq_all(ispa))))
        case('so4')
            base_charge(ispa) = -2d0
        case('no3')
            base_charge(ispa) = -1d0
        case('si')
            base_charge(ispa) = 0d0
        case('na','k')
            base_charge(ispa) = 1d0
        case('fe2','mg','ca')
            base_charge(ispa) = 2d0
        case('fe3','al')
            base_charge(ispa) = 3d0
        case default 
            print*,'error in charge assignment'
            stop
    endselect 
enddo

f1 = 0d0
df1 = 0d0
df12 = 0d0
df1dmaq = 0d0
df1dmgas = 0d0

f1 = f1 + prox**(ss_add+1d0) - kw*prox**(ss_add-1d0)
df1 = df1 + (ss_add+1d0)*prox**ss_add - kw*(ss_add-1d0)*prox**(ss_add-2d0)
if (print_res) write(88,'(3A11)', advance='no') 'z','h', 'oh'

! adding charges coming from aq species in eq with gases
! pCO2
f1 = f1  -  k1*kco2*pco2x*prox**(ss_add-1d0)  -  2d0*k2*k1*kco2*pco2x*prox**(ss_add-2d0)
df1 = df1  -  k1*kco2*pco2x*(ss_add-1d0)*prox**(ss_add-2d0)  -  2d0*k2*k1*kco2*pco2x*(ss_add-2d0)*prox**(ss_add-3d0)
df1dmgas(ipco2,:) = df1dmgas(ipco2,:) -  k1*kco2*1d0*prox**(ss_add-1d0)  -  2d0*k2*k1*kco2*1d0*prox**(ss_add-2d0)
if (print_res) write(88,'(2A11)', advance='no') 'hco3','co3'
! pNH3
f1 = f1  +  pnh3x*knh3/k1nh3*prox**(ss_add+1d0)
df1 = df1  +  pnh3x*knh3/k1nh3*(ss_add+1d0)*prox**ss_add
df1dmgas(ipnh3,:) = df1dmgas(ipnh3,:)  +  1d0*knh3/k1nh3*prox**(ss_add+1d0)
if (print_res) write(88,'(A11)', advance='no') 'nh4'

do ispa = 1, nsp_aq_all
    
    f1 = f1 + base_charge(ispa)*maqf_loc(ispa,:)*prox**(ss_add)
    df1 = df1 + ( &
        & + base_charge(ispa)*dmaqf_dpro(ispa,:)*prox**(ss_add)  &
        & + base_charge(ispa)*maqf_loc(ispa,:)*(ss_add)*prox**(ss_add-1d0)  &
        & )
    df12 = df12 + base_charge(ispa)*dmaqf_dso4f(ispa,:)*prox**(ss_add) 
    df1dmaq(ispa,:) = df1dmaq(ispa,:) + base_charge(ispa)*dmaqf_dmaq(ispa,:)*prox**(ss_add) 
    df1dmgas(ipco2,:) = df1dmgas(ipco2,:) + base_charge(ispa)*dmaqf_dpco2(ispa,:) *prox**(ss_add)
    if (print_res) write(88,'(A11)', advance='no') trim(adjustl(chraq_all(ispa)))
    
    ! annions
    if (trim(adjustl(chraq_all(ispa)))=='no3' .or. trim(adjustl(chraq_all(ispa)))=='so4') then 
        
        ! account for speces associated with H+
        do ispa_h = 1,4
            if ( keqaq_h(ispa,ispa_h) > 0d0) then 
                rspa_h = real(ispa_h,kind=8)
                f1 = f1 + (base_charge(ispa) + rspa_h)*keqaq_h(ispa,ispa_h)*maqf_loc(ispa,:)*prox**(rspa_h+ss_add)
                df1 = df1 + ( & 
                    & + (base_charge(ispa) + rspa_h) &
                    &        *keqaq_h(ispa,ispa_h)*maqf_loc(ispa,:)*(rspa_h+ss_add)*prox**(rspa_h+ss_add-1d0) &
                    & + (base_charge(ispa) + rspa_h)*keqaq_h(ispa,ispa_h)*dmaqf_dpro(ispa,:)*prox**(rspa_h+ss_add) &
                    & )
                df12 = df12 + (& 
                    & + (base_charge(ispa) + rspa_h)*keqaq_h(ispa,ispa_h)*dmaqf_dso4f(ispa,:)*prox**(rspa_h+ss_add) &
                    & )
                df1dmaq(ispa,:) = df1dmaq(ispa,:) + (& 
                    & + (base_charge(ispa) + rspa_h)*keqaq_h(ispa,ispa_h)*dmaqf_dmaq(ispa,:)*prox**(rspa_h+ss_add) &
                    & )
                df1dmgas(ipco2,:) = df1dmgas(ipco2,:) + (& 
                    & + (base_charge(ispa) + rspa_h)*keqaq_h(ispa,ispa_h)*dmaqf_dpco2(ispa,:)*prox**(rspa_h+ss_add) &
                    & )
                if (print_res) then 
                    write(chrint,'(I1)') ispa_h
                    write(88,'(A11)', advance='no') 'h'//trim(adjustl(chrint))//trim(adjustl(chraq_all(ispa)))
                endif 
            endif 
        enddo 
    ! cations
    else 
        ! account for hydrolysis speces
        do ispa_h = 1,4
            if ( keqaq_h(ispa,ispa_h) > 0d0) then 
                rspa_h = real(ispa_h,kind=8)
                f1 = f1 + (base_charge(ispa) - rspa_h)*keqaq_h(ispa,ispa_h)*maqf_loc(ispa,:)*prox**(ss_add-rspa_h)
                df1 = df1 + ( &
                    & + (base_charge(ispa) - rspa_h) &
                    &       *keqaq_h(ispa,ispa_h)*maqf_loc(ispa,:)*(ss_add-rspa_h)*prox**(ss_add-rspa_h-1d0) &
                    & + (base_charge(ispa) - rspa_h)*keqaq_h(ispa,ispa_h)*dmaqf_dpro(ispa,:)*prox**(ss_add-rspa_h) &
                    & )
                df12 = df12 + ( &
                    & + (base_charge(ispa) - rspa_h)*keqaq_h(ispa,ispa_h)*dmaqf_dso4f(ispa,:)*prox**(ss_add-rspa_h) &
                    & )
                df1dmaq(ispa,:) = df1dmaq(ispa,:) + ( &
                    & + (base_charge(ispa) - rspa_h)*keqaq_h(ispa,ispa_h)*dmaqf_dmaq(ispa,:)*prox**(ss_add-rspa_h) &
                    & )
                df1dmgas(ipco2,:) = df1dmgas(ipco2,:) + ( &
                    & + (base_charge(ispa) - rspa_h)*keqaq_h(ispa,ispa_h)*dmaqf_dpco2(ispa,:)*prox**(ss_add-rspa_h) &
                    & )
                if (print_res) then 
                    write(chrint,'(I1)') ispa_h
                    write(88,'(A11)', advance='no') trim(adjustl(chraq_all(ispa)))//'(oh)'//trim(adjustl(chrint))
                endif 
            endif 
        enddo 
        ! account for species associated with CO3-- (ispa_c =1) and HCO3- (ispa_c =2)
        do ispa_c = 1,2
            if ( keqaq_c(ispa,ispa_c) > 0d0) then 
                if (ispa_c == 1) then ! with CO3--
                    f1 = f1 + (base_charge(ispa)-2d0)*keqaq_c(ispa,ispa_c)*maqf_loc(ispa,:)*k1*k2*kco2*pco2x*prox**(ss_add-2d0)
                    df1 = df1 + ( & 
                        & + (base_charge(ispa)-2d0) &
                        &       *keqaq_c(ispa,ispa_c)*maqf_loc(ispa,:)*k1*k2*kco2*pco2x*(ss_add-2d0)*prox**(ss_add-3d0) &
                        & + (base_charge(ispa)-2d0)*keqaq_c(ispa,ispa_c)*dmaqf_dpro(ispa,:)*k1*k2*kco2*pco2x*prox**(ss_add-2d0) &
                        & )
                    df12 = df12 + ( & 
                        & + (base_charge(ispa)-2d0)*keqaq_c(ispa,ispa_c)*dmaqf_dso4f(ispa,:)*k1*k2*kco2*pco2x*prox**(ss_add-2d0) &
                        & )
                    df1dmaq(ispa,:) = df1dmaq(ispa,:) + ( & 
                        & + (base_charge(ispa)-2d0)*keqaq_c(ispa,ispa_c)*dmaqf_dmaq(ispa,:)*k1*k2*kco2*pco2x*prox**(ss_add-2d0) &
                        & )
                    df1dmgas(ipco2,:) = df1dmgas(ipco2,:) + ( & 
                        & + (base_charge(ispa)-2d0)*keqaq_c(ispa,ispa_c)*dmaqf_dpco2(ispa,:)*k1*k2*kco2*pco2x*prox**(ss_add-2d0) &
                        & + (base_charge(ispa)-2d0)*keqaq_c(ispa,ispa_c)*maqf_loc(ispa,:)*k1*k2*kco2*1d0*prox**(ss_add-2d0) &
                        & )
                    if (print_res) write(88,'(A11)', advance='no') trim(adjustl(chraq_all(ispa)))//'(co3)'
                elseif (ispa_c == 2) then ! with HCO3-
                    f1 = f1 + (base_charge(ispa)-1d0)*keqaq_c(ispa,ispa_c)*maqf_loc(ispa,:)*k1*k2*kco2*pco2x*prox**(ss_add-1d0)
                    df1 = df1 + ( & 
                        & + (base_charge(ispa)-1d0) &
                        &       *keqaq_c(ispa,ispa_c)*maqf_loc(ispa,:)*k1*k2*kco2*pco2x*(ss_add-1d0)*prox**(ss_add-2d0) &
                        & + (base_charge(ispa)-1d0)*keqaq_c(ispa,ispa_c)*dmaqf_dpro(ispa,:)*k1*k2*kco2*pco2x*prox**(ss_add-1d0) &
                        & )
                    df12 = df12 + ( & 
                        & + (base_charge(ispa)-1d0)*keqaq_c(ispa,ispa_c)*dmaqf_dso4f(ispa,:)*k1*k2*kco2*pco2x*prox**(ss_add-1d0) &
                        & )
                    df1dmaq(ispa,:) = df1dmaq(ispa,:) + ( & 
                        & + (base_charge(ispa)-1d0)*keqaq_c(ispa,ispa_c)*dmaqf_dmaq(ispa,:)*k1*k2*kco2*pco2x*prox**(ss_add-1d0) &
                        & )
                    df1dmgas(ipco2,:) = df1dmgas(ipco2,:) + ( & 
                        & + (base_charge(ispa)-1d0)*keqaq_c(ispa,ispa_c)*dmaqf_dpco2(ispa,:)*k1*k2*kco2*pco2x*prox**(ss_add-1d0) &
                        & + (base_charge(ispa)-1d0)*keqaq_c(ispa,ispa_c)*maqf_loc(ispa,:)*k1*k2*kco2*1d0*prox**(ss_add-1d0) &
                        & )
                    if (print_res) write(88,'(A11)', advance='no') trim(adjustl(chraq_all(ispa)))//'(hco3)'
                endif 
            endif 
        enddo 
        ! account for complexation with free SO4
        do ispa_s = 1,2
            if ( keqaq_s(ispa,ispa_s) > 0d0) then 
                rspa_s = real(ispa_s,kind=8)
                f1 = f1 + (base_charge(ispa)-2d0*rspa_s)*keqaq_s(ispa,ispa_s)*maqf_loc(ispa,:)*so4f**rspa_s*prox**ss_add
                df1 = df1 + ( & 
                    & + (base_charge(ispa)-2d0*rspa_s)*keqaq_s(ispa,ispa_s)*dmaqf_dpro(ispa,:)*so4f**rspa_s*prox**ss_add & 
                    & + (base_charge(ispa)-2d0*rspa_s) &
                    &       *keqaq_s(ispa,ispa_s)*maqf_loc(ispa,:)*so4f**rspa_s*ss_add*prox**(ss_add-1d0) & 
                    & )
                df12 = df12 + ( & 
                    & + (base_charge(ispa)-2d0*rspa_s) &
                    &       *keqaq_s(ispa,ispa_s)*maqf_loc(ispa,:)*rspa_s*so4f**(rspa_s-1d0)*prox**ss_add & 
                    & + (base_charge(ispa)-2d0*rspa_s)*keqaq_s(ispa,ispa_s)*dmaqf_dso4f(ispa,:)*so4f**rspa_s*prox**ss_add & 
                    & )
                df1dmaq(ispa,:) = df1dmaq(ispa,:) + ( & 
                    & + (base_charge(ispa)-2d0*rspa_s)*keqaq_s(ispa,ispa_s)*dmaqf_dmaq(ispa,:)*so4f**rspa_s*prox**ss_add & 
                    & )
                df1dmgas(ipco2,:) = df1dmgas(ipco2,:) + ( & 
                    & + (base_charge(ispa)-2d0*rspa_s)*keqaq_s(ispa,ispa_s)*dmaqf_dpco2(ispa,:)*so4f**rspa_s*prox**ss_add & 
                    & )
                if (print_res) then 
                    write(chrint,'(I1)') ispa_s
                    write(88,'(A11)', advance='no') trim(adjustl(chraq_all(ispa)))//'(so4)'//trim(adjustl(chrint))
                endif 
            endif 
        enddo 
        ! currently NO3 complexation with cations are ignored
    endif 
enddo     

if (print_res) write(88,'(A11)') 'tot_charge'

f1_chk = 0d0
ss_add = 0d0
if (print_res) then
    if (any(isnan(prox)) .or. any(prox <= 0d0)) then 
        print *, 'H+ conc is nan or <=0'
        print *, prox
        stop
    endif 
    do iz = 1, nz
        f1_chk(iz) = f1_chk(iz) + prox(iz)**(ss_add+1d0) - kw*prox(iz)**(ss_add-1d0)
        write(88,'(3E11.3)', advance='no') z(iz),prox(iz), kw/prox(iz)

        ! adding charges coming from aq species in eq with gases
        ! pCO2
        f1_chk(iz) = f1_chk(iz)  -  k1*kco2*pco2x(iz)*prox(iz)**(ss_add-1d0)  -  2d0*k2*k1*kco2*pco2x(iz)*prox(iz)**(ss_add-2d0)
        write(88,'(2E11.3)', advance='no')    k1*kco2*pco2x(iz)/prox(iz),  k2*k1*kco2*pco2x(iz)/prox(iz)**2d0
        ! pNH3
        f1_chk(iz) = f1_chk(iz)  +  pnh3x(iz)*knh3/k1nh3*prox(iz)**(ss_add+1d0)
        write(88,'(E11.3)', advance='no')    pnh3x(iz)*knh3/k1nh3*prox(iz)

        do ispa = 1, nsp_aq_all
            
            f1_chk(iz) = f1_chk(iz) + base_charge(ispa)*maqf_loc(ispa,iz)*prox(iz)**(ss_add)
            write(88,'(E11.3)', advance='no') maqf_loc(ispa,iz) 
            
            ! annions
            if (trim(adjustl(chraq_all(ispa)))=='no3' .or. trim(adjustl(chraq_all(ispa)))=='so4') then 
                
                ! account for speces associated with H+
                do ispa_h = 1,4
                    if ( keqaq_h(ispa,ispa_h) > 0d0) then 
                        rspa_h = real(ispa_h,kind=8)
                        f1_chk(iz) = f1_chk(iz) &
                            & + (base_charge(ispa) + rspa_h)*keqaq_h(ispa,ispa_h)*maqf_loc(ispa,iz)*prox(iz)**(rspa_h+ss_add)
                        write(88,'(E11.3)', advance='no') keqaq_h(ispa,ispa_h)*maqf_loc(ispa,iz)*prox(iz)**rspa_h
                    endif 
                enddo 
            ! cations
            else 
                ! account for hydrolysis speces
                do ispa_h = 1,4
                    if ( keqaq_h(ispa,ispa_h) > 0d0) then 
                        rspa_h = real(ispa_h,kind=8)
                        f1_chk(iz) = f1_chk(iz) &
                            & + (base_charge(ispa) - rspa_h)*keqaq_h(ispa,ispa_h)*maqf_loc(ispa,iz)*prox(iz)**(ss_add-rspa_h)
                        write(88,'(E11.3)', advance='no') keqaq_h(ispa,ispa_h)*maqf_loc(ispa,iz)/prox(iz)**rspa_h
                    endif 
                enddo 
                ! account for species associated with CO3-- (ispa_c =1) and HCO3- (ispa_c =2)
                do ispa_c = 1,2
                    if ( keqaq_c(ispa,ispa_c) > 0d0) then 
                        if (ispa_c == 1) then ! with CO3--
                            f1_chk(iz) = f1_chk(iz) + (base_charge(ispa)-2d0) &
                                & *keqaq_c(ispa,ispa_c)*maqf_loc(ispa,iz)*k1*k2*kco2*pco2x(iz)*prox(iz)**(ss_add-2d0)
                            write(88,'(E11.3)', advance='no') &
                                & keqaq_c(ispa,ispa_c)*maqf_loc(ispa,iz)*k1*k2*kco2*pco2x(iz)/prox(iz)**2d0
                        elseif (ispa_c == 2) then ! with HCO3-
                            f1_chk(iz) = f1_chk(iz) + (base_charge(ispa)-1d0) &
                                & *keqaq_c(ispa,ispa_c)*maqf_loc(ispa,iz)*k1*k2*kco2*pco2x(iz)*prox(iz)**(ss_add-1d0)
                            write(88,'(E11.3)', advance='no') &
                                & keqaq_c(ispa,ispa_c)*maqf_loc(ispa,iz)*k1*k2*kco2*pco2x(iz)/prox(iz)
                        endif 
                    endif 
                enddo 
                ! account for complexation with free SO4
                do ispa_s = 1,2
                    if ( keqaq_s(ispa,ispa_s) > 0d0) then 
                        rspa_s = real(ispa_s,kind=8)
                        f1_chk(iz) = f1_chk(iz)  + (base_charge(ispa)-2d0*rspa_s) &
                            & *keqaq_s(ispa,ispa_s)*maqf_loc(ispa,iz)*so4f(iz)**rspa_s*prox(iz)**ss_add
                        write(88,'(E11.3)', advance='no') keqaq_s(ispa,ispa_s)*maqf_loc(ispa,iz)*so4f(iz)**rspa_s
                    endif 
                enddo 
                ! currently NO3 complexation with cations is ignored
            endif 
        enddo     
        write(88,'(E11.3)') f1_chk(iz)
    enddo 
endif 

if (print_res) close(88)

endsubroutine calc_charge

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine calc_so4_balance( &
    & nz,nsp_aq_all,nsp_gas_all &
    & ,chraq_all,chrgas_all &
    & ,keqaq_h,keqaq_s  &
    & ,maqf_loc &
    & ,dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2 &
    & ,prox,so4f,so4x &
    & ,ph_add_order &
    & ,df2,df21,df2dmaq,df2dmgas &! output
    & ,f2 &! output
    & )
! f2 = prox**2d0*so4x - prox**2d0*so4f*( 1d0+k1so4*prox &
    ! & +k1kso4*kf &
    ! & +k1naso4*naf &
    ! & +k1caso4*caf &
    ! & +k1mgso4*mgf &
    ! & +k1fe2so4*fe2f &
    ! & +k1also4*alf &
    ! & +k1fe3so4*fe3f &
    ! & )
implicit none

integer,intent(in)::nz,nsp_aq_all,nsp_gas_all
character(5),dimension(nsp_aq_all)::chraq_all
character(5),dimension(nsp_gas_all)::chrgas_all
real(kind=8),intent(in)::ph_add_order
real(kind=8),dimension(nsp_aq_all,4),intent(in)::keqaq_h
real(kind=8),dimension(nsp_aq_all,2),intent(in)::keqaq_s
real(kind=8),dimension(nsp_aq_all,nz),intent(in)::maqf_loc
real(kind=8),dimension(nsp_aq_all,nz),intent(in)::dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2
real(kind=8),dimension(nz),intent(in)::prox,so4f,so4x
real(kind=8),dimension(nz),intent(out)::f2,df2,df21
real(kind=8),dimension(nsp_aq_all,nz),intent(out)::df2dmaq
real(kind=8),dimension(nsp_gas_all,nz),intent(out)::df2dmgas

integer ispa,ispa_h,ispa_s,ipco2
real(kind=8) rspa_h,rspa_s,ss_add

ipco2 = findloc(chrgas_all,'pco2',dim=1)

ss_add = ph_add_order

f2 = 0d0
df2 = 0d0
df21 = 0d0
df2dmaq = 0d0
df2dmgas = 0d0

f2 = so4x*prox**ss_add - so4f*prox**ss_add
! print *,'so4x',so4x*prox**ss_add
! print *,'so4f',- so4f*prox**ss_add
df2 = - 1d0*prox**ss_add
df21 = so4x*ss_add*prox**(ss_add-1d0) - so4f*ss_add*prox**(ss_add-1d0)
df2dmaq(findloc(chraq_all,'so4',dim=1),:) =  1d0*prox**ss_add 

f2 = 1d0
df2 = 0d0 
df21 = 0d0

do ispa = 1, nsp_aq_all
    
    selectcase(trim(adjustl(chraq_all(ispa))))
        ! annions
        case('so4')  
        
            ! account for SO4 association with H+
            do ispa_h = 1,4
                if ( keqaq_h(ispa,ispa_h) > 0d0) then 
                    rspa_h = real(ispa_h,kind=8)
                    f2 = f2 + keqaq_h(ispa,ispa_h)*prox**(rspa_h)
                    ! print *,chraq_all(ispa),- keqaq_h(ispa,ispa_h)*so4f*prox**(rspa_h+ss_add)
                    ! df2 = df2 + keqaq_h(ispa,ispa_h)*1d0*prox**(rspa_h)
                    ! df21 = df21 - keqaq_h(ispa,ispa_h)*so4f*(rspa_h+ss_add)*prox**(rspa_h+ss_add-1d0)
                    df21 = df21 + keqaq_h(ispa,ispa_h)*rspa_h*prox**(rspa_h-1d0)
                endif 
            enddo 
        
        case('no3')
            ! do nothing because it is not associated with so4
        
        ! cations
        case('k','na','si','mg','ca','fe2','fe3','al')  
            ! account for complexation with free SO4
            do ispa_s = 1,2
                if ( keqaq_s(ispa,ispa_s) > 0d0) then
                    rspa_s = real(ispa_s,kind=8)
                    f2 = f2 + rspa_s*keqaq_s(ispa,ispa_s)*maqf_loc(ispa,:)*so4f**(rspa_s-1d0)
                    ! print *,chraq_all(ispa),- rspa_s*keqaq_s(ispa,ispa_s)*maqf_loc(ispa,:)*so4f**rspa_s*prox**ss_add
                    ! df2 = df2 - ( &
                        ! & + rspa_s*keqaq_s(ispa,ispa_s)*maqf_loc(ispa,:)*rspa_s*so4f**(rspa_s-1d0)*prox**ss_add &
                        ! & + rspa_s*keqaq_s(ispa,ispa_s)*dmaqf_dso4f(ispa,:)*so4f**rspa_s*prox**ss_add &
                        ! & )
                    df2 = df2 + rspa_s*keqaq_s(ispa,ispa_s)*dmaqf_dso4f(ispa,:)*so4f**(rspa_s-1d0)
                    ! df21 = df21 - ( &
                        ! & + rspa_s*keqaq_s(ispa,ispa_s)*dmaqf_dpro(ispa,:)*so4f**rspa_s*prox**ss_add &
                        ! & + rspa_s*keqaq_s(ispa,ispa_s)*maqf_loc(ispa,:)*so4f**rspa_s*ss_add*prox**(ss_add-1d0) &
                        ! & )
                    df21 = df21 + rspa_s*keqaq_s(ispa,ispa_s)*dmaqf_dpro(ispa,:)*so4f**(rspa_s-1d0)
                    df2dmaq(ispa,:) = df2dmaq(ispa,:) - ( &
                        & + rspa_s*keqaq_s(ispa,ispa_s)*dmaqf_dmaq(ispa,:)*so4f**rspa_s*prox**ss_add &
                        & )
                    df2dmgas(ipco2,:) = df2dmgas(ipco2,:) - ( &
                        & + rspa_s*keqaq_s(ispa,ispa_s)*dmaqf_dpco2(ispa,:)*so4f**rspa_s*prox**ss_add &
                        & )
                endif 
            enddo 
        
        case default
            
            print*,'** error: you should not come here @ calc_so4_balance'
            stop
        
    endselect
enddo     

df2 = - 1d0*prox**ss_add*f2 - so4f*prox**ss_add*df2
df21 = so4x*ss_add*prox**(ss_add-1d0) - so4f*ss_add*prox**(ss_add-1d0)*f2 - so4f*prox**ss_add*df21
f2 = so4x*prox**ss_add - so4f*prox**ss_add*f2

endsubroutine calc_so4_balance

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine calc_so4( &
    & nz,so4x,nax,kx,mgx,cax,fe2x,alx,fe3x,pco2x,prox &! input 
    & ,nsp_gas_all,nsp_aq_all,chraq_all,chrgas_all,keqgas_h,keqaq_h,keqaq_c,keqaq_s &! input 
    & ,so4f,so4_error &! output
    & )
implicit none 

integer,intent(in)::nz,nsp_gas_all,nsp_aq_all
real(kind=8),dimension(nz),intent(in)::so4x,nax,kx,mgx,cax,fe2x,alx,fe3x,pco2x,prox
real(kind=8),dimension(nz),intent(out)::so4f
real(kind=8),dimension(nsp_gas_all,3),intent(in)::keqgas_h
real(kind=8),dimension(nsp_aq_all,4),intent(in)::keqaq_h
real(kind=8),dimension(nsp_aq_all,2),intent(in)::keqaq_c
real(kind=8),dimension(nsp_aq_all,2),intent(in)::keqaq_s
character(5),dimension(nsp_aq_all),intent(in)::chraq_all
character(5),dimension(nsp_gas_all),intent(in)::chrgas_all
logical,intent(out)::so4_error

real(kind=8) kco2,k1,k2,k1si,k2si,k1mg,k1mgco3,k1mghco3,k1ca,k1caco3,k1cahco3,k1al,k2al,k3al,k4al &
    & ,k1fe2,k1fe2co3,k1fe2hco3,k1fe3,k2fe3,k3fe3,k4fe3,k1naco3,k1nahco3,k1so4,k1kso4,k1naso4  &
    & ,k1caso4,k1mgso4,k1fe2so4,k1also4,k1also42,k1fe3so4,k1fe3so42

real(kind=8),dimension(nz)::f,df
real(kind=8) error,tol 
integer iter

integer ieqgas_h0,ieqgas_h1,ieqgas_h2
data ieqgas_h0,ieqgas_h1,ieqgas_h2/1,2,3/

integer ieqaq_h1,ieqaq_h2,ieqaq_h3,ieqaq_h4
data ieqaq_h1,ieqaq_h2,ieqaq_h3,ieqaq_h4/1,2,3,4/

integer ieqaq_co3,ieqaq_hco3
data ieqaq_co3,ieqaq_hco3/1,2/

integer ieqaq_so4,ieqaq_so42
data ieqaq_so4,ieqaq_so42/1,2/


kco2 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h0)
k1 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h1)
k2 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h2)
k1si = keqaq_h(findloc(chraq_all,'si',dim=1),ieqaq_h1)
k2si = keqaq_h(findloc(chraq_all,'si',dim=1),ieqaq_h2)
k1mg = keqaq_h(findloc(chraq_all,'mg',dim=1),ieqaq_h1)
k1mgco3 = keqaq_c(findloc(chraq_all,'mg',dim=1),ieqaq_co3)
k1mghco3  = keqaq_c(findloc(chraq_all,'mg',dim=1),ieqaq_hco3)
k1ca = keqaq_h(findloc(chraq_all,'ca',dim=1),ieqaq_h1)
k1caco3 = keqaq_c(findloc(chraq_all,'ca',dim=1),ieqaq_co3)
k1cahco3 = keqaq_c(findloc(chraq_all,'ca',dim=1),ieqaq_hco3)
k1al= keqaq_h(findloc(chraq_all,'al',dim=1),ieqaq_h1)
k2al= keqaq_h(findloc(chraq_all,'al',dim=1),ieqaq_h2)
k3al= keqaq_h(findloc(chraq_all,'al',dim=1),ieqaq_h3)
k4al= keqaq_h(findloc(chraq_all,'al',dim=1),ieqaq_h4)
k1fe2 = keqaq_h(findloc(chraq_all,'fe2',dim=1),ieqaq_h1)
k1fe2co3 = keqaq_c(findloc(chraq_all,'fe2',dim=1),ieqaq_co3)
k1fe2hco3  = keqaq_c(findloc(chraq_all,'fe2',dim=1),ieqaq_hco3)
k1fe3= keqaq_h(findloc(chraq_all,'fe3',dim=1),ieqaq_h1)
k2fe3= keqaq_h(findloc(chraq_all,'fe3',dim=1),ieqaq_h2)
k3fe3= keqaq_h(findloc(chraq_all,'fe3',dim=1),ieqaq_h3)
k4fe3= keqaq_h(findloc(chraq_all,'fe3',dim=1),ieqaq_h4)
k1naco3 = keqaq_c(findloc(chraq_all,'na',dim=1),ieqaq_co3)
k1nahco3  = keqaq_c(findloc(chraq_all,'na',dim=1),ieqaq_hco3)

k1so4 = keqaq_h(findloc(chraq_all,'so4',dim=1),ieqaq_h1)
k1naso4 = keqaq_s(findloc(chraq_all,'na',dim=1),ieqaq_so4)
k1kso4 = keqaq_s(findloc(chraq_all,'k',dim=1),ieqaq_so4)
k1caso4 = keqaq_s(findloc(chraq_all,'ca',dim=1),ieqaq_so4)
k1mgso4 = keqaq_s(findloc(chraq_all,'mg',dim=1),ieqaq_so4)
k1fe2so4 = keqaq_s(findloc(chraq_all,'fe2',dim=1),ieqaq_so4)
k1also4 = keqaq_s(findloc(chraq_all,'al',dim=1),ieqaq_so4)
k1fe3so4 = keqaq_s(findloc(chraq_all,'fe3',dim=1),ieqaq_so4)
k1also42 = keqaq_s(findloc(chraq_all,'al',dim=1),ieqaq_so42)
k1fe3so42 = keqaq_s(findloc(chraq_all,'fe3',dim=1),ieqaq_so42)


error = 1d4
tol = 1d-6

iter = 0

so4f = so4x

do while (error > tol)
    f = so4x - so4f*( 1d0+k1so4/prox &
        & +k1kso4*kx/(1d0+k1kso4*so4f) &
        & +k1naso4*nax/(1d0+k1naco3*k1*k2*kco2*pco2x/prox**2d0+k1nahco3*k1*k2*kco2*pco2x/prox+k1naso4*so4f) &
        & +k1caso4*cax/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox+k1caso4*so4f) &
        & +k1mgso4*mgx/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox+k1mgso4*so4f) &
        & +k1fe2so4*fe2x/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox+k1fe2so4*so4f) &
        & +k1also4*alx/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0+k1also4*so4f) &
        & +k1fe3so4*fe3x/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0+k1fe3so4*so4f) &
        & )
        
    df = - 1d0*( 1d0+k1so4/prox &
        & +k1kso4*kx/(1d0+k1kso4*so4f) &
        & +k1naso4*nax/(1d0+k1naco3*k1*k2*kco2*pco2x/prox**2d0+k1nahco3*k1*k2*kco2*pco2x/prox+k1naso4*so4f) &
        & +k1caso4*cax/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox+k1caso4*so4f) &
        & +k1mgso4*mgx/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox+k1mgso4*so4f) &
        & +k1fe2so4*fe2x/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox+k1fe2so4*so4f) &
        & +k1also4*alx/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0+k1also4*so4f) &
        & +k1fe3so4*fe3x/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0+k1fe3so4*so4f) &
        & ) &
        & - so4f*( &
        & +k1kso4*kx*(-1d0)/(1d0+k1kso4*so4f)**2d0*k1kso4 &
        & +k1naso4*nax*(-1d0)/(1d0+k1naco3*k1*k2*kco2*pco2x/prox**2d0+k1nahco3*k1*k2*kco2*pco2x/prox+k1naso4*so4f)**2d0*k1naso4 &
        & +k1caso4*cax*(-1d0) &
        &       /(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox+k1caso4*so4f)**2d0*k1caso4 &
        & +k1mgso4*mgx*(-1d0) &
        &       /(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox+k1mgso4*so4f)**2d0*k1mgso4 &
        & +k1fe2so4*fe2x*(-1d0) &
        &       /(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox+k1fe2so4*so4f)**2d0*k1fe2so4 &
        & +k1also4*alx*(-1d0)/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0+k1also4*so4f)**2d0*k1also4 &
        & +k1fe3so4*fe3x*(-1d0)/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0+k1fe3so4*so4f)**2d0*k1fe3so4 &
        & )
    
    
    df = df*so4f
    so4f = so4f*exp( -f/df )
    error = maxval(abs(exp( -f/df )-1d0))
    if (any(isnan(f)).or.any(isnan(df))) then 
        ! print *,so4x
        ! print *,any(isnan(f))
        ! print *,f
        ! print *,any(isnan(df))
        ! print *,df
        so4_error = .true.
        exit
    endif 
    if (isnan(error)) error = 1d4
    
    ! print *,iter,error
    
    iter = iter + 1
enddo 

so4_error = .false.
if (any(isnan(so4f))) then     
    print *, so4f
    print*,'so4f is nan'
    print*,so4x
    so4_error = .true.
    stop
endif 

endsubroutine calc_so4

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine calc_omega_v3( &
    & nz,nsp_aq,nsp_gas,nsp_aq_all,nsp_sld_all,nsp_gas_all,nsp_aq_cnst,nsp_gas_cnst &! input 
    & ,chraq,chraq_cnst,chraq_all,chrsld_all,chrgas,chrgas_cnst,chrgas_all &!input
    & ,maqx,maqc,mgasx,mgasc,keqgas_h,keqaq_h,keqaq_c,keqsld_all &! input
    & ,prox,mineral &! input 
    & ,omega &! output
    & )
implicit none
integer,intent(in)::nz
real(kind=8):: keqfo,keqab,keqan,keqcc,k1,k2,kco2,k1si,k2si,k1mg,k1mgco3,k1mghco3,k1ca,k1caco3,k1cahco3 &
    & ,k1al,k2al,k3al,k4al,keqka,keqgb,keqct,k1fe2,k1fe2co3,k1fe2hco3,keqfa,k1fe3,k2fe3,k3fe3,k4fe3,keqgt &
    & ,keqcabd,keqdp,keqhb,keqkfs,keqamsi
real(kind=8),dimension(nz),intent(in):: prox
real(kind=8),dimension(nz):: pco2x,cax,mgx,six,nax,alx,po2x,fe2x,fe3x,kx
real(kind=8),dimension(nz),intent(out):: omega
character(5),intent(in):: mineral

integer,intent(in)::nsp_aq,nsp_gas,nsp_aq_all,nsp_gas_all,nsp_sld_all,nsp_aq_cnst,nsp_gas_cnst
character(5),dimension(nsp_aq),intent(in)::chraq
character(5),dimension(nsp_aq_cnst),intent(in)::chraq_cnst
character(5),dimension(nsp_aq_all),intent(in)::chraq_all
character(5),dimension(nsp_gas),intent(in)::chrgas
character(5),dimension(nsp_gas_cnst),intent(in)::chrgas_cnst
character(5),dimension(nsp_gas_all),intent(in)::chrgas_all
character(5),dimension(nsp_sld_all),intent(in)::chrsld_all
real(kind=8),dimension(nsp_aq,nz),intent(in)::maqx
real(kind=8),dimension(nsp_aq_cnst,nz),intent(in)::maqc
real(kind=8),dimension(nsp_gas,nz),intent(in)::mgasx
real(kind=8),dimension(nsp_gas_cnst,nz),intent(in)::mgasc
real(kind=8),dimension(nsp_gas_all,3),intent(in)::keqgas_h
real(kind=8),dimension(nsp_aq_all,4),intent(in)::keqaq_h
real(kind=8),dimension(nsp_aq_all,2),intent(in)::keqaq_c
real(kind=8),dimension(nsp_sld_all),intent(in)::keqsld_all

integer ieqgas_h0,ieqgas_h1,ieqgas_h2
data ieqgas_h0,ieqgas_h1,ieqgas_h2/1,2,3/

integer ieqaq_h1,ieqaq_h2,ieqaq_h3,ieqaq_h4
data ieqaq_h1,ieqaq_h2,ieqaq_h3,ieqaq_h4/1,2,3,4/

integer ieqaq_co3,ieqaq_hco3
data ieqaq_co3,ieqaq_hco3/1,2/

kco2 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h0)
k1 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h1)
k2 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h2)
keqab = keqsld_all(findloc(chrsld_all,'ab',dim=1))
keqfo = keqsld_all(findloc(chrsld_all,'fo',dim=1))
keqan = keqsld_all(findloc(chrsld_all,'an',dim=1))
keqcc = keqsld_all(findloc(chrsld_all,'cc',dim=1))
k1si = keqaq_h(findloc(chraq_all,'si',dim=1),ieqaq_h1)
k2si = keqaq_h(findloc(chraq_all,'si',dim=1),ieqaq_h2)
k1mg = keqaq_h(findloc(chraq_all,'mg',dim=1),ieqaq_h1)
k1mgco3 = keqaq_c(findloc(chraq_all,'mg',dim=1),ieqaq_co3)
k1mghco3  = keqaq_c(findloc(chraq_all,'mg',dim=1),ieqaq_hco3)
k1ca = keqaq_h(findloc(chraq_all,'ca',dim=1),ieqaq_h1)
k1caco3 = keqaq_c(findloc(chraq_all,'ca',dim=1),ieqaq_co3)
k1cahco3 = keqaq_c(findloc(chraq_all,'ca',dim=1),ieqaq_hco3)
k1al= keqaq_h(findloc(chraq_all,'al',dim=1),ieqaq_h1)
k2al= keqaq_h(findloc(chraq_all,'al',dim=1),ieqaq_h2)
k3al= keqaq_h(findloc(chraq_all,'al',dim=1),ieqaq_h3)
k4al= keqaq_h(findloc(chraq_all,'al',dim=1),ieqaq_h4)
keqka = keqsld_all(findloc(chrsld_all,'ka',dim=1))
keqgb =  keqsld_all(findloc(chrsld_all,'gb',dim=1))
keqct =  keqsld_all(findloc(chrsld_all,'ct',dim=1))
k1fe2 = keqaq_h(findloc(chraq_all,'fe2',dim=1),ieqaq_h1)
k1fe2co3 = keqaq_c(findloc(chraq_all,'fe2',dim=1),ieqaq_co3)
k1fe2hco3  = keqaq_c(findloc(chraq_all,'fe2',dim=1),ieqaq_hco3)
keqfa = keqsld_all(findloc(chrsld_all,'fa',dim=1))
k1fe3= keqaq_h(findloc(chraq_all,'fe3',dim=1),ieqaq_h1)
k2fe3= keqaq_h(findloc(chraq_all,'fe3',dim=1),ieqaq_h2)
k3fe3= keqaq_h(findloc(chraq_all,'fe3',dim=1),ieqaq_h3)
k4fe3= keqaq_h(findloc(chraq_all,'fe3',dim=1),ieqaq_h4)
keqgt = keqsld_all(findloc(chrsld_all,'gt',dim=1))
keqcabd = keqsld_all(findloc(chrsld_all,'cabd',dim=1))
keqdp = keqsld_all(findloc(chrsld_all,'dp',dim=1))
keqhb = keqsld_all(findloc(chrsld_all,'hb',dim=1))
keqkfs = keqsld_all(findloc(chrsld_all,'kfs',dim=1))
keqamsi = keqsld_all(findloc(chrsld_all,'amsi',dim=1))

nax = 0d0
kx = 0d0

if (any(chraq=='na')) then 
    nax = maqx(findloc(chraq,'na',dim=1),:)
elseif (any(chraq_cnst=='na')) then 
    nax = maqc(findloc(chraq_cnst,'na',dim=1),:)
endif 
if (any(chraq=='k')) then 
    kx = maqx(findloc(chraq,'k',dim=1),:)
elseif (any(chraq_cnst=='k')) then 
    kx = maqc(findloc(chraq_cnst,'k',dim=1),:)
endif 

six =0d0
cax =0d0
mgx =0d0
fe2x =0d0
fe3x =0d0
alx =0d0
pco2x =0d0

if (any(chraq=='si')) then 
    six = maqx(findloc(chraq,'si',dim=1),:)
elseif (any(chraq_cnst=='si')) then 
    six = maqc(findloc(chraq_cnst,'si',dim=1),:)
endif 
if (any(chraq=='ca')) then 
    cax = maqx(findloc(chraq,'ca',dim=1),:)
elseif (any(chraq_cnst=='ca')) then 
    cax = maqc(findloc(chraq_cnst,'ca',dim=1),:)
endif 
if (any(chraq=='mg')) then 
    mgx = maqx(findloc(chraq,'mg',dim=1),:)
elseif (any(chraq_cnst=='mg')) then 
    mgx = maqc(findloc(chraq_cnst,'mg',dim=1),:)
endif 
if (any(chraq=='fe2')) then 
    fe2x = maqx(findloc(chraq,'fe2',dim=1),:)
elseif (any(chraq_cnst=='fe2')) then 
    fe2x = maqc(findloc(chraq_cnst,'fe2',dim=1),:)
endif 
if (any(chraq=='al')) then 
    alx = maqx(findloc(chraq,'al',dim=1),:)
elseif (any(chraq_cnst=='al')) then 
    alx = maqc(findloc(chraq_cnst,'al',dim=1),:)
endif 
if (any(chraq=='fe3')) then 
    fe3x = maqx(findloc(chraq,'fe3',dim=1),:)
elseif (any(chraq_cnst=='fe3')) then 
    fe3x = maqc(findloc(chraq_cnst,'fe3',dim=1),:)
endif 
if (any(chrgas=='pco2')) then 
    pco2x = mgasx(findloc(chrgas,'pco2',dim=1),:)
elseif (any(chrgas_cnst=='pco2')) then 
    pco2x = mgasc(findloc(chrgas_cnst,'pco2',dim=1),:)
endif 
if (any(chrgas=='po2')) then 
    po2x = mgasx(findloc(chrgas,'po2',dim=1),:)
elseif (any(chrgas_cnst=='po2')) then 
    po2x = mgasc(findloc(chrgas_cnst,'po2',dim=1),:)
endif 

select case(trim(adjustl(mineral)))
    case('fo')
    ! Fo + 4H+ = 2Mg2+ + SiO2(aq) + 2H2O 
        omega = & 
            & mgx**2d0/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox)**2d0 &
            & *six/(1d0+k1si/prox+k2si/prox**2d0)/prox**4d0/keqfo
        ! omega = mgx**2d0/(prox+k1mg+k1mgco3*k1*k2*kco2*pco2x/prox+k1mghco3*k1*k2*kco2*pco2x)**2d0 & 
            ! & *six/(prox**2d0+k1si*prox+k2si)/keqfo
    case('fa')
    ! Fa + 4H+ = 2Fe2+ + SiO2(aq) + 2H2O 
        omega = & 
            & fe2x**2d0/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox)**2d0 &
            & *six/(1d0+k1si/prox+k2si/prox**2d0)/prox**4d0/keqfa
    case('ab')
    ! NaAlSi3O8 + 4 H+ = Na+ + Al3+ + 3SiO2 + 2H2O
        omega = & 
            & nax*alx/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0) &
            & *six**3d0/(1d0+k1si/prox+k2si/prox**2d0)**3d0/prox**4d0/keqab
    case('kfs')
    ! K-feldspar  + 4 H+  = 2 H2O  + K+  + Al+++  + 3 SiO2(aq)
        omega = & 
            & kx &
            & *alx/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0) &
            & *six**3d0/(1d0+k1si/prox+k2si/prox**2d0)**3d0 &
            & /prox**4d0 &
            & /keqkfs 
    case('an')
    ! CaAl2Si2O8 + 8H+ = Ca2+ + 2 Al3+ + 2SiO2 + 4H2O
        omega = & 
            & cax/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox) &
            & *alx**2d0/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0)**2d0 &
            & *six**2d0/(1d0+k1si/prox+k2si/prox**2d0)**2d0 &
            & /prox**8d0/keqan
    case('cc')
        omega = cax/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox) &
            & *k1*k2*kco2*pco2x/(prox**2d0)/keqcc
        ! omega = cax/(prox**2d0/(k1*k2*kco2*pco2x)+k1ca/prox/(k1*k2*kco2*pco2x)+k1caco3+k1cahco3*prox)/keqcc
    case('ka')
    ! Al2Si2O5(OH)4 + 6 H+ = H2O + 2 H4SiO4 + 2 Al+3 
        omega = &
            & alx**2d0/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0)**2d0 &
            & *six**2d0/(1d0+k1si/prox+k2si/prox**2d0)**2d0 &
            & /prox**6d0/keqka
    case('gb')
    ! Al(OH)3 + 3 H+ = Al+3 + 3 H2O 
        omega = &
            & alx/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0) &
            & /prox**3d0/keqgb
    case('amsi')
    ! SiO2 + 2 H2O = H4SiO4
        omega = &
            & six/(1d0+k1si/prox+k2si/prox**2d0) &
            & /keqamsi
    case('gt')
    !  Fe(OH)3 + 3 H+ = Fe+3 + 2 H2O
        omega = &
            & fe3x/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0) &
            & /prox**3d0/keqgt
    case('ct')
    ! Mg3Si2O5(OH)4 + 6 H+ = H2O + 2 H4SiO4 + 3 Mg+2
        omega = &
            & mgx**3d0/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox)**3d0 &
            & *six**2d0/(1d0+k1si/prox+k2si/prox**2d0)**2d0  &
            & /prox**6d0/keqct
    case('cabd')
    ! Beidellit-Ca  + 7.32 H+  = 4.66 H2O  + 2.33 Al+++  + 3.67 SiO2(aq)  + .165 Ca++
        omega = &
            & cax**(1d0/6d0)/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox)**(1d0/6d0) &
            & *alx**(7d0/3d0)/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0)**(7d0/3d0) &
            & *six**(11d0/3d0)/(1d0+k1si/prox+k2si/prox**2d0)**(11d0/3d0) &
            & /prox**(22d0/3d0)/keqcabd
    case('dp')
    ! Diopside  + 4 H+  = Ca++  + 2 H2O  + Mg++  + 2 SiO2(aq)
        omega = &
            & cax/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox) &
            & *mgx/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox) &
            & *six**(2d0)/(1d0+k1si/prox+k2si/prox**2d0)**(2d0) &
            & /prox**(4d0)/keqdp
    case('hb')
    ! Hedenbergite  + 4 H+  = 2 H2O  + 2 SiO2(aq)  + Fe++  + Ca++
        omega = &
            & cax/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox) &
            & *fe2x/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox) &
            & *six**(2d0)/(1d0+k1si/prox+k2si/prox**2d0)**(2d0) &
            & /prox**(4d0)/keqhb
    case('py')
    ! omega is defined so that kpy*poro*hr*mvpy*1d-6*mpyx*(1d0-omega_py) = kpy*poro*hr*mvpy*1d-6*mpyx*po2x**0.5d0
    ! i.e., 1.0 - omega_py = po2x**0.5 
        ! omega = 1d0 - po2x**0.5d0
        omega = 1d0 - po2x**0.5d0*merge(0d0,1d0,po2x<1d-20)
        ! omega = 0d0
        
    case('om')
    ! omega is defined so that kpy*poro*hr*mvpy*1d-6*mpyx*(1d0-omega_py) = kpy*poro*hr*mvpy*1d-6*mpyx*po2x**0.5d0
    ! i.e., 1.0 - omega_py = po2x**0.5 
        ! omega = 1d0 - po2x**0.5d0
        omega = 1d0 
        ! omega = 0d0
    case('omb')
    ! omega is defined so that kpy*poro*hr*mvpy*1d-6*mpyx*(1d0-omega_py) = kpy*poro*hr*mvpy*1d-6*mpyx*po2x**0.5d0
    ! i.e., 1.0 - omega_py = po2x**0.5 
        ! omega = 1d0 - po2x**0.5d0
        omega = 1d0 
        ! omega = 0d0
    case default 
        omega = 1d0
endselect

if (any(isnan(omega))) then 
    print *,'nan in calc_omega_v3'
    stop
endif 

endsubroutine calc_omega_v3

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine calc_omega_dev( &
    & nz,nsp_aq,nsp_gas,nsp_aq_all,nsp_sld_all,nsp_gas_all,nsp_aq_cnst,nsp_gas_cnst &! input 
    & ,chraq,chraq_cnst,chraq_all,chrsld_all,chrgas,chrgas_cnst,chrgas_all &!input
    & ,maqx,maqc,mgasx,mgasc,keqgas_h,keqaq_h,keqaq_c,keqsld_all,mgasth_all &! input
    & ,prox,mineral,sp_name &! input 
    & ,omega,domega_dmsp,omega_error &! output
    & )
implicit none
integer,intent(in)::nz
real(kind=8):: keqfo,keqab,keqan,keqcc,k1,k2,kco2,k1si,k2si,k1mg,k1mgco3,k1mghco3,k1ca,k1caco3,k1cahco3 &
    & ,k1al,k2al,k3al,k4al,keqka,keqgb,keqct,k1fe2,k1fe2co3,k1fe2hco3,keqfa,k1fe3,k2fe3,k3fe3,k4fe3,keqgt &
    & ,keqcabd,keqdp,keqhb,keqkfs,keqamsi,keqg1,keqg2,keqg3,po2th,k1naco3,k1nahco3
real(kind=8),dimension(nz),intent(in):: prox
real(kind=8),dimension(nz):: pco2x,cax,mgx,six,nax,alx,po2x,fe2x,fe3x,kx
real(kind=8),dimension(nz),intent(out):: domega_dmsp
real(kind=8),dimension(nz),intent(out):: omega
logical,intent(out)::omega_error
character(5),intent(in):: mineral,sp_name

integer,intent(in)::nsp_aq,nsp_gas,nsp_aq_all,nsp_gas_all,nsp_sld_all,nsp_aq_cnst,nsp_gas_cnst
character(5),dimension(nsp_aq),intent(in)::chraq
character(5),dimension(nsp_aq_cnst),intent(in)::chraq_cnst
character(5),dimension(nsp_aq_all),intent(in)::chraq_all
character(5),dimension(nsp_gas),intent(in)::chrgas
character(5),dimension(nsp_gas_cnst),intent(in)::chrgas_cnst
character(5),dimension(nsp_gas_all),intent(in)::chrgas_all
character(5),dimension(nsp_sld_all),intent(in)::chrsld_all
real(kind=8),dimension(nsp_aq,nz),intent(in)::maqx
real(kind=8),dimension(nsp_aq_cnst,nz),intent(in)::maqc
real(kind=8),dimension(nsp_gas,nz),intent(in)::mgasx
real(kind=8),dimension(nsp_gas_cnst,nz),intent(in)::mgasc
real(kind=8),dimension(nsp_gas_all),intent(in)::mgasth_all
real(kind=8),dimension(nsp_gas_all,3),intent(in)::keqgas_h
real(kind=8),dimension(nsp_aq_all,4),intent(in)::keqaq_h
real(kind=8),dimension(nsp_aq_all,2),intent(in)::keqaq_c
real(kind=8),dimension(nsp_sld_all),intent(in)::keqsld_all

integer ieqgas_h0,ieqgas_h1,ieqgas_h2
data ieqgas_h0,ieqgas_h1,ieqgas_h2/1,2,3/

integer ieqaq_h1,ieqaq_h2,ieqaq_h3,ieqaq_h4
data ieqaq_h1,ieqaq_h2,ieqaq_h3,ieqaq_h4/1,2,3,4/

integer ieqaq_co3,ieqaq_hco3
data ieqaq_co3,ieqaq_hco3/1,2/

kco2 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h0)
k1 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h1)
k2 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h2)
keqab = keqsld_all(findloc(chrsld_all,'ab',dim=1))
keqfo = keqsld_all(findloc(chrsld_all,'fo',dim=1))
keqan = keqsld_all(findloc(chrsld_all,'an',dim=1))
keqcc = keqsld_all(findloc(chrsld_all,'cc',dim=1))
k1si = keqaq_h(findloc(chraq_all,'si',dim=1),ieqaq_h1)
k2si = keqaq_h(findloc(chraq_all,'si',dim=1),ieqaq_h2)
k1mg = keqaq_h(findloc(chraq_all,'mg',dim=1),ieqaq_h1)
k1mgco3 = keqaq_c(findloc(chraq_all,'mg',dim=1),ieqaq_co3)
k1mghco3  = keqaq_c(findloc(chraq_all,'mg',dim=1),ieqaq_hco3)
k1ca = keqaq_h(findloc(chraq_all,'ca',dim=1),ieqaq_h1)
k1caco3 = keqaq_c(findloc(chraq_all,'ca',dim=1),ieqaq_co3)
k1cahco3 = keqaq_c(findloc(chraq_all,'ca',dim=1),ieqaq_hco3)
k1al= keqaq_h(findloc(chraq_all,'al',dim=1),ieqaq_h1)
k2al= keqaq_h(findloc(chraq_all,'al',dim=1),ieqaq_h2)
k3al= keqaq_h(findloc(chraq_all,'al',dim=1),ieqaq_h3)
k4al= keqaq_h(findloc(chraq_all,'al',dim=1),ieqaq_h4)
keqka = keqsld_all(findloc(chrsld_all,'ka',dim=1))
keqgb =  keqsld_all(findloc(chrsld_all,'gb',dim=1))
keqct =  keqsld_all(findloc(chrsld_all,'ct',dim=1))
k1fe2 = keqaq_h(findloc(chraq_all,'fe2',dim=1),ieqaq_h1)
k1fe2co3 = keqaq_c(findloc(chraq_all,'fe2',dim=1),ieqaq_co3)
k1fe2hco3  = keqaq_c(findloc(chraq_all,'fe2',dim=1),ieqaq_hco3)
keqfa = keqsld_all(findloc(chrsld_all,'fa',dim=1))
k1fe3= keqaq_h(findloc(chraq_all,'fe3',dim=1),ieqaq_h1)
k2fe3= keqaq_h(findloc(chraq_all,'fe3',dim=1),ieqaq_h2)
k3fe3= keqaq_h(findloc(chraq_all,'fe3',dim=1),ieqaq_h3)
k4fe3= keqaq_h(findloc(chraq_all,'fe3',dim=1),ieqaq_h4)
keqgt = keqsld_all(findloc(chrsld_all,'gt',dim=1))
keqcabd = keqsld_all(findloc(chrsld_all,'cabd',dim=1))
keqdp = keqsld_all(findloc(chrsld_all,'dp',dim=1))
keqhb = keqsld_all(findloc(chrsld_all,'hb',dim=1))
keqkfs = keqsld_all(findloc(chrsld_all,'kfs',dim=1))
keqamsi = keqsld_all(findloc(chrsld_all,'amsi',dim=1))
keqg1 = keqsld_all(findloc(chrsld_all,'g1',dim=1))
keqg2 = keqsld_all(findloc(chrsld_all,'g2',dim=1))
keqg3 = keqsld_all(findloc(chrsld_all,'g3',dim=1))
k1naco3 = keqaq_c(findloc(chraq_all,'na',dim=1),ieqaq_co3)
k1nahco3 = keqaq_c(findloc(chraq_all,'na',dim=1),ieqaq_hco3)


po2th = mgasth_all(findloc(chrgas_all,'po2',dim=1))


nax = 0d0
kx = 0d0

if (any(chraq=='na')) then 
    nax = maqx(findloc(chraq,'na',dim=1),:)
elseif (any(chraq_cnst=='na')) then 
    nax = maqc(findloc(chraq_cnst,'na',dim=1),:)
endif 
if (any(chraq=='k')) then 
    kx = maqx(findloc(chraq,'k',dim=1),:)
elseif (any(chraq_cnst=='k')) then 
    kx = maqc(findloc(chraq_cnst,'k',dim=1),:)
endif 

six =0d0
cax =0d0
mgx =0d0
fe2x =0d0
fe3x =0d0
alx =0d0
pco2x =0d0

if (any(chraq=='si')) then 
    six = maqx(findloc(chraq,'si',dim=1),:)
elseif (any(chraq_cnst=='si')) then 
    six = maqc(findloc(chraq_cnst,'si',dim=1),:)
endif 
if (any(chraq=='ca')) then 
    cax = maqx(findloc(chraq,'ca',dim=1),:)
elseif (any(chraq_cnst=='ca')) then 
    cax = maqc(findloc(chraq_cnst,'ca',dim=1),:)
endif 
if (any(chraq=='mg')) then 
    mgx = maqx(findloc(chraq,'mg',dim=1),:)
elseif (any(chraq_cnst=='mg')) then 
    mgx = maqc(findloc(chraq_cnst,'mg',dim=1),:)
endif 
if (any(chraq=='fe2')) then 
    fe2x = maqx(findloc(chraq,'fe2',dim=1),:)
elseif (any(chraq_cnst=='fe2')) then 
    fe2x = maqc(findloc(chraq_cnst,'fe2',dim=1),:)
endif 
if (any(chraq=='al')) then 
    alx = maqx(findloc(chraq,'al',dim=1),:)
elseif (any(chraq_cnst=='al')) then 
    alx = maqc(findloc(chraq_cnst,'al',dim=1),:)
endif 
if (any(chraq=='fe3')) then 
    fe3x = maqx(findloc(chraq,'fe3',dim=1),:)
elseif (any(chraq_cnst=='fe3')) then 
    fe3x = maqc(findloc(chraq_cnst,'fe3',dim=1),:)
endif 
if (any(chrgas=='pco2')) then 
    pco2x = mgasx(findloc(chrgas,'pco2',dim=1),:)
elseif (any(chrgas_cnst=='pco2')) then 
    pco2x = mgasc(findloc(chrgas_cnst,'pco2',dim=1),:)
endif 
if (any(chrgas=='po2')) then 
    po2x = mgasx(findloc(chrgas,'po2',dim=1),:)
elseif (any(chrgas_cnst=='po2')) then 
    po2x = mgasc(findloc(chrgas_cnst,'po2',dim=1),:)
endif 

select case(trim(adjustl(mineral)))
    case('fo')
    ! Fo + 4H+ = 2Mg2+ + SiO2(aq) + 2H2O 
        omega = ( & 
            & mgx**2d0/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox)**2d0 &
            & *six/(1d0+k1si/prox+k2si/prox**2d0)/prox**4d0/keqfo &
            & )
        ! omega = mgx**2d0/(prox+k1mg+k1mgco3*k1*k2*kco2*pco2x/prox+k1mghco3*k1*k2*kco2*pco2x)**2d0 & 
            ! & *six/(prox**2d0+k1si*prox+k2si)/keqfo
        select case(trim(adjustl(sp_name)))
            case('pro')
                domega_dmsp = ( & 
                    & mgx**2d0*(-2d0)/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox)**3d0 &
                    & *(k1mg*(-1d0)/prox**2d0+k1mgco3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0 &
                        & +k1mghco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0) &
                    & *six/(1d0+k1si/prox+k2si/prox**2d0)/prox**4d0/keqfo &
                    ! 
                    & +mgx**2d0/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox)**2d0 &
                    & *six*(-1d0)/(1d0+k1si/prox+k2si/prox**2d0)**2d0 &
                    & *(k1si*(-1d0)/prox**2d0+k2si*(-2d0)/prox**3d0) &
                    & /prox**4d0/keqfo &
                    ! 
                    & +mgx**2d0/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox)**2d0 &
                    & *six/(1d0+k1si/prox+k2si/prox**2d0) &
                    & *(-4d0)/prox**5d0/keqfo &
                    & )
            case('mg')
                domega_dmsp = ( & 
                    & 2d0*mgx/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox)**2d0 &
                    & *six/(1d0+k1si/prox+k2si/prox**2d0)/prox**4d0/keqfo &
                    & )
            case('si')
                domega_dmsp = ( & 
                    & mgx**2d0/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox)**2d0 &
                    & *1d0/(1d0+k1si/prox+k2si/prox**2d0)/prox**4d0/keqfo &
                    & )
            case('pco2')
                domega_dmsp = ( & 
                    & mgx**2d0*(-2d0)/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox)**3d0 &
                    & *(k1mgco3*k1*k2*kco2*1d0/prox**2d0+k1mghco3*k1*k2*kco2*1d0/prox) &
                    & *six/(1d0+k1si/prox+k2si/prox**2d0)/prox**4d0/keqfo &
                    & )
            case default 
                domega_dmsp = 0d0
        endselect 
        
    case('fa')
    ! Fa + 4H+ = 2Fe2+ + SiO2(aq) + 2H2O 
        omega = ( & 
            & fe2x**2d0/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox)**2d0 &
            & *six/(1d0+k1si/prox+k2si/prox**2d0)/prox**4d0/keqfa &
            & )
            
        ! copied and pasted from Fo case with mg changed with fe2 and fo changed with fa    
        select case(trim(adjustl(sp_name)))
            case('pro')
                domega_dmsp = ( & 
                    & fe2x**2d0*(-2d0)/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox)**3d0 &
                    & *(k1fe2*(-1d0)/prox**2d0+k1fe2co3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0 &
                            & +k1fe2hco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0) &
                    & *six/(1d0+k1si/prox+k2si/prox**2d0)/prox**4d0/keqfa &
                    ! 
                    & +fe2x**2d0/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox)**2d0 &
                    & *six*(-1d0)/(1d0+k1si/prox+k2si/prox**2d0)**2d0 &
                    & *(k1si*(-1d0)/prox**2d0+k2si*(-2d0)/prox**3d0) &
                    & /prox**4d0/keqfa &
                    ! 
                    & +fe2x**2d0/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox)**2d0 &
                    & *six/(1d0+k1si/prox+k2si/prox**2d0) &
                    & *(-4d0)/prox**5d0/keqfa &
                    & )
            case('fe2')
                domega_dmsp = ( & 
                    & 2d0*fe2x/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox)**2d0 &
                    & *six/(1d0+k1si/prox+k2si/prox**2d0)/prox**4d0/keqfa &
                    & )
            case('si')
                domega_dmsp = ( & 
                    & fe2x**2d0/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox)**2d0 &
                    & *1d0/(1d0+k1si/prox+k2si/prox**2d0)/prox**4d0/keqfa &
                    & )
            case('pco2')
                domega_dmsp = ( & 
                    & fe2x**2d0*(-2d0)/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox)**3d0 &
                    & *(k1fe2co3*k1*k2*kco2*1d0/prox**2d0+k1fe2hco3*k1*k2*kco2*1d0/prox) &
                    & *six/(1d0+k1si/prox+k2si/prox**2d0)/prox**4d0/keqfa &
                    & )
            case default 
                domega_dmsp = 0d0
        endselect 
        
    case('ab')
    ! NaAlSi3O8 + 4 H+ = Na+ + Al3+ + 3SiO2 + 2H2O
        omega = ( & 
            & nax/(1d0+k1naco3*k1*k2*kco2*pco2x/prox**2d0+k1nahco3*k1*k2*kco2*pco2x/prox) & 
            & *alx/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0) &
            & *six**3d0/(1d0+k1si/prox+k2si/prox**2d0)**3d0 &
            & /prox**4d0 &
            & /keqab &
            & )
            
        select case(trim(adjustl(sp_name)))
            case('pro')
                domega_dmsp = ( & 
                    & nax*(-1d0)/(1d0+k1naco3*k1*k2*kco2*pco2x/prox**2d0+k1nahco3*k1*k2*kco2*pco2x/prox)**2d0 & 
                    & *(k1naco3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0+k1nahco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0) &
                    & *alx/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0) &
                    & *six**3d0/(1d0+k1si/prox+k2si/prox**2d0)**3d0 &
                    & /prox**4d0 &
                    & /keqab &
                    !
                    & +nax/(1d0+k1naco3*k1*k2*kco2*pco2x/prox**2d0+k1nahco3*k1*k2*kco2*pco2x/prox) & 
                    & *alx*(-1d0)/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0)**2d0 &
                    & *(k1al*(-1d0)/prox**2d0+k2al*(-2d0)/prox**3d0+k3al*(-3d0)/prox**4d0+k4al*(-4d0)/prox**5d0) &
                    & *six**3d0/(1d0+k1si/prox+k2si/prox**2d0)**3d0 &
                    & /prox**4d0 &
                    & /keqab &
                    ! 
                    & +nax/(1d0+k1naco3*k1*k2*kco2*pco2x/prox**2d0+k1nahco3*k1*k2*kco2*pco2x/prox) & 
                    & *alx/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0) &
                    & *six**3d0*(-3d0)/(1d0+k1si/prox+k2si/prox**2d0)**4d0 &
                    & *(k1si*(-1d0)/prox**2d0+k2si*(-2d0)/prox**3d0) &
                    & /prox**4d0 &
                    & /keqab &
                    ! 
                    & +nax/(1d0+k1naco3*k1*k2*kco2*pco2x/prox**2d0+k1nahco3*k1*k2*kco2*pco2x/prox) & 
                    & *alx/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0) &
                    & *six**3d0/(1d0+k1si/prox+k2si/prox**2d0)**3d0 &
                    & *(-4d0)/prox**5d0 &
                    & /keqab &
                    & )
            case('na')
                domega_dmsp = ( & 
                    & 1d0/(1d0+k1naco3*k1*k2*kco2*pco2x/prox**2d0+k1nahco3*k1*k2*kco2*pco2x/prox) & 
                    & *alx/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0) &
                    & *six**3d0/(1d0+k1si/prox+k2si/prox**2d0)**3d0 &
                    & /prox**4d0 &
                    & /keqab &
                    & )
            case('al')
                domega_dmsp = ( & 
                    & nax/(1d0+k1naco3*k1*k2*kco2*pco2x/prox**2d0+k1nahco3*k1*k2*kco2*pco2x/prox) & 
                    & *1d0/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0) &
                    & *six**3d0/(1d0+k1si/prox+k2si/prox**2d0)**3d0 &
                    & /prox**4d0 &
                    & /keqab &
                    & )
            case('si')
                domega_dmsp = ( & 
                    & nax/(1d0+k1naco3*k1*k2*kco2*pco2x/prox**2d0+k1nahco3*k1*k2*kco2*pco2x/prox) & 
                    & *alx/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0) &
                    & *3d0*six**2d0/(1d0+k1si/prox+k2si/prox**2d0)**3d0 &
                    & /prox**4d0 &
                    & /keqab &
                    & )
            case default 
                domega_dmsp = 0d0
        endselect 
        
        
    case('kfs')
    ! K-feldspar  + 4 H+  = 2 H2O  + K+  + Al+++  + 3 SiO2(aq)
        omega = ( & 
            & kx &
            & *alx/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0) &
            & *six**3d0/(1d0+k1si/prox+k2si/prox**2d0)**3d0 &
            & /prox**4d0 &
            & /keqkfs   &
            & )
            
        ! copied and pasted from ab case with na changed with k and ab changed with kfs  
        select case(trim(adjustl(sp_name)))
            case('pro')
                domega_dmsp = ( & 
                    & kx & 
                    & *alx*(-1d0)/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0)**2d0 &
                    & *(k1al*(-1d0)/prox**2d0+k2al*(-2d0)/prox**3d0+k3al*(-3d0)/prox**4d0+k4al*(-4d0)/prox**5d0) &
                    & *six**3d0/(1d0+k1si/prox+k2si/prox**2d0)**3d0 &
                    & /prox**4d0 &
                    & /keqkfs &
                    ! 
                    & +kx & 
                    & *alx/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0) &
                    & *six**3d0*(-3d0)/(1d0+k1si/prox+k2si/prox**2d0)**4d0 &
                    & *(k1si*(-1d0)/prox**2d0+k2si*(-2d0)/prox**3d0) &
                    & /prox**4d0 &
                    & /keqkfs &
                    ! 
                    & +kx & 
                    & *alx/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0) &
                    & *six**3d0/(1d0+k1si/prox+k2si/prox**2d0)**3d0 &
                    & *(-4d0)/prox**5d0 &
                    & /keqkfs &
                    & )
            case('k')
                domega_dmsp = ( & 
                    & 1d0 & 
                    & *alx/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0) &
                    & *six**3d0/(1d0+k1si/prox+k2si/prox**2d0)**3d0 &
                    & /prox**4d0 &
                    & /keqkfs &
                    & )
            case('al')
                domega_dmsp = ( & 
                    & kx & 
                    & *1d0/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0) &
                    & *six**3d0/(1d0+k1si/prox+k2si/prox**2d0)**3d0 &
                    & /prox**4d0 &
                    & /keqkfs &
                    & )
            case('si')
                domega_dmsp = ( & 
                    & kx & 
                    & *alx/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0) &
                    & *3d0*six**2d0/(1d0+k1si/prox+k2si/prox**2d0)**3d0 &
                    & /prox**4d0 &
                    & /keqkfs &
                    & )
            case default 
                domega_dmsp = 0d0
        endselect 
        
        
    case('an')
    ! CaAl2Si2O8 + 8H+ = Ca2+ + 2 Al3+ + 2SiO2 + 4H2O
        omega = ( & 
            & cax/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox) &
            & *alx**2d0/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0)**2d0 &
            & *six**2d0/(1d0+k1si/prox+k2si/prox**2d0)**2d0 &
            & /prox**8d0 &
            & /keqan &
            & )
            
        select case(trim(adjustl(sp_name)))
            case('pro')
                domega_dmsp = ( & 
                    & cax*(-1d0)/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox)**2d0 &
                    & *(k1ca*(-1d0)/prox**2d0+k1caco3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0 &
                                                        & +k1cahco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0) &
                    & *alx**2d0/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0)**2d0 &
                    & *six**2d0/(1d0+k1si/prox+k2si/prox**2d0)**2d0 &
                    & /prox**8d0 &
                    & /keqan &
                    ! 
                    & +cax/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox) &
                    & *alx**2d0*(-2d0)/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0)**3d0 &
                    & *(k1al*(-1d0)/prox**2d0+k2al*(-2d0)/prox**3d0+k3al*(-3d0)/prox**4d0+k4al*(-4d0)/prox**5d0) &
                    & *six**2d0/(1d0+k1si/prox+k2si/prox**2d0)**2d0 &
                    & /prox**8d0 &
                    & /keqan &
                    ! 
                    & +cax/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox) &
                    & *alx**2d0/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0)**2d0 &
                    & *six**2d0*(-2d0)/(1d0+k1si/prox+k2si/prox**2d0)**3d0 &
                    & *(k1si*(-1d0)/prox**2d0+k2si*(-2d0)/prox**3d0) &
                    & /prox**8d0 &
                    & /keqan &
                    ! 
                    & +cax/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox) &
                    & *alx**2d0/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0)**2d0 &
                    & *six**2d0/(1d0+k1si/prox+k2si/prox**2d0)**2d0 &
                    & *(-8d0)/prox**9d0 &
                    & /keqan &
                    & )
            case('pco2')
                domega_dmsp = ( & 
                    & cax*(-1d0)/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox)**2d0 &
                    & *(k1caco3*k1*k2*kco2*1d0/prox**2d0+k1cahco3*k1*k2*kco2*1d0/prox) &
                    & *alx**2d0/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0)**2d0 &
                    & *six**2d0/(1d0+k1si/prox+k2si/prox**2d0)**2d0 &
                    & /prox**8d0 &
                    & /keqan &
                    & )
            case('ca')
                domega_dmsp = ( & 
                    & 1d0/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox) &
                    & *alx**2d0/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0)**2d0 &
                    & *six**2d0/(1d0+k1si/prox+k2si/prox**2d0)**2d0 &
                    & /prox**8d0 &
                    & /keqan &
                    & )
            case('al')
                domega_dmsp = ( & 
                    & cax/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox) &
                    & *2d0*alx/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0)**2d0 &
                    & *six**2d0/(1d0+k1si/prox+k2si/prox**2d0)**2d0 &
                    & /prox**8d0 &
                    & /keqan &
                    & )
            case('si')
                domega_dmsp = ( & 
                    & cax/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox) &
                    & *alx**2d0/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0)**2d0 &
                    & *1d0**2d0/(1d0+k1si/prox+k2si/prox**2d0)**2d0 &
                    & /prox**8d0 &
                    & /keqan &
                    & )
            case default 
                domega_dmsp = 0d0
        endselect 
        
        
    case('cc')
        omega = ( &
            & cax/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox) &
            & *k1*k2*kco2*pco2x/(prox**2d0) &
            & /keqcc &
            & )
        ! omega = cax/(prox**2d0/(k1*k2*kco2*pco2x)+k1ca/prox/(k1*k2*kco2*pco2x)+k1caco3+k1cahco3*prox)/keqcc
            
        select case(trim(adjustl(sp_name)))
            case('pro')
                ! ca++ dependence on pH is from 'an' case
                domega_dmsp = ( & 
                    & cax*(-1d0)/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox)**2d0 &
                    & *(k1ca*(-1d0)/prox**2d0+k1caco3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0 &
                                                                    & +k1cahco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0) &
                    & *k1*k2*kco2*pco2x/(prox**2d0) &
                    & /keqcc &
                    ! 
                    & +cax/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox) &
                    & *k1*k2*kco2*pco2x*(-2d0)/(prox**3d0) &
                    & /keqcc &
                    & )
            case('pco2')
                ! ca++ dependence on pCO2 is from 'an' case
                domega_dmsp = ( & 
                    & cax*(-1d0)/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox)**2d0 &
                    & *(k1caco3*k1*k2*kco2*1d0/prox**2d0+k1cahco3*k1*k2*kco2*1d0/prox) &
                    & *k1*k2*kco2*pco2x/(prox**2d0) &
                    & /keqcc &
                    ! 
                    & +cax/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox) &
                    & *k1*k2*kco2*1d0/(prox**2d0) &
                    & /keqcc &
                    & )
            case('ca')
                domega_dmsp = ( & 
                    & 1d0/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox) &
                    & *k1*k2*kco2*pco2x/(prox**2d0) &
                    & /keqcc &
                    & )
            case default 
                domega_dmsp = 0d0
        endselect 
        
        
    case('ka')
    ! Al2Si2O5(OH)4 + 6 H+ = H2O + 2 H4SiO4 + 2 Al+3 
        omega = ( &
            & alx**2d0/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0)**2d0 &
            & *six**2d0/(1d0+k1si/prox+k2si/prox**2d0)**2d0 &
            & /prox**6d0 &
            & /keqka &
            & )
            
        select case(trim(adjustl(sp_name)))
            case('pro')
                ! ph dependences of al and si are from an case
                domega_dmsp = ( & 
                    & alx**2d0*(-2d0)/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0)**3d0 &
                    & *(k1al*(-1d0)/prox**2d0+k2al*(-2d0)/prox**3d0+k3al*(-3d0)/prox**4d0+k4al*(-4d0)/prox**5d0) &
                    & *six**2d0/(1d0+k1si/prox+k2si/prox**2d0)**2d0 &
                    & /prox**6d0 &
                    & /keqka &
                    ! 
                    & +alx**2d0/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0)**2d0 &
                    & *six**2d0*(-2d0)/(1d0+k1si/prox+k2si/prox**2d0)**3d0 &
                    & *(k1si*(-1d0)/prox**2d0+k2si*(-2d0)/prox**3d0) &
                    & /prox**6d0 &
                    & /keqka &
                    ! 
                    & +alx**2d0/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0)**2d0 &
                    & *six**2d0/(1d0+k1si/prox+k2si/prox**2d0)**2d0 &
                    & *(-6d0)/prox**7d0 &
                    & /keqka &
                    ! 
                    & )
            case('al')
                domega_dmsp = ( & 
                    & 2d0*alx/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0)**2d0 &
                    & *six**2d0/(1d0+k1si/prox+k2si/prox**2d0)**2d0 &
                    & /prox**6d0 &
                    & /keqka &
                    & )
            case('si')
                domega_dmsp = ( & 
                    & alx**2d0/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0)**2d0 &
                    & *six*2d0/(1d0+k1si/prox+k2si/prox**2d0)**2d0 &
                    & /prox**6d0 &
                    & /keqka &
                    & )
            case default 
                domega_dmsp = 0d0
        endselect 
        
        
    case('gb')
    ! Al(OH)3 + 3 H+ = Al+3 + 3 H2O 
        omega = ( &
            & alx/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0) &
            & /prox**3d0 &
            & /keqgb &
            & )
            
        select case(trim(adjustl(sp_name)))
            case('pro')
                ! ph dependence of al is from an case
                domega_dmsp = ( & 
                    & alx*(-1d0)/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0)**2d0 &
                    & *(k1al*(-1d0)/prox**2d0+k2al*(-2d0)/prox**3d0+k3al*(-3d0)/prox**4d0+k4al*(-4d0)/prox**5d0) &
                    & /prox**3d0 &
                    & /keqgb &
                    ! 
                    & +alx/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0) &
                    & *(-3d0)/prox**4d0 &
                    & /keqgb &
                    ! 
                    & )
            case('al')
                domega_dmsp = ( & 
                    & 1d0/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0) &
                    & /prox**3d0 &
                    & /keqgb &
                    & )
            case default 
                domega_dmsp = 0d0
        endselect 
        
    case('amsi')
    ! SiO2 + 2 H2O = H4SiO4
        omega = ( &
            & six/(1d0+k1si/prox+k2si/prox**2d0) &
            & /keqamsi &
            & )
            
        select case(trim(adjustl(sp_name)))
            case('pro')
                ! ph dependence of si is from above
                domega_dmsp = ( & 
                    & six*(-1d0)/(1d0+k1si/prox+k2si/prox**2d0)**2d0 &
                    & *(k1si*(-1d0)/prox**2d0+k2si*(-2d0)/prox**3d0) &
                    & /keqamsi &
                    ! 
                    & )
            case('si')
                domega_dmsp = ( & 
                    & 1d0/(1d0+k1si/prox+k2si/prox**2d0) &
                    & /keqamsi &
                    & )
            case default 
                domega_dmsp = 0d0
        endselect 
        
        
    case('gt')
    !  Fe(OH)3 + 3 H+ = Fe+3 + 2 H2O
        omega = (&
            & fe3x/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0) &
            & /prox**3d0 &
            & /keqgt &
            & )
            
        ! copied and pasted from gb case with replacing al and gb with fe3 and gt respectively
        select case(trim(adjustl(sp_name)))
            case('pro')
                domega_dmsp = ( & 
                    & fe3x*(-1d0)/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0)**2d0 &
                    & *(k1fe3*(-1d0)/prox**2d0+k2fe3*(-2d0)/prox**3d0+k3fe3*(-3d0)/prox**4d0+k4fe3*(-4d0)/prox**5d0) &
                    & /prox**3d0 &
                    & /keqgt &
                    ! 
                    & +fe3x/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0) &
                    & *(-3d0)/prox**4d0 &
                    & /keqgt &
                    ! 
                    & )
            case('fe3')
                domega_dmsp = ( & 
                    & 1d0/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0) &
                    & /prox**3d0 &
                    & /keqgt &
                    & )
            case default 
                domega_dmsp = 0d0
        endselect 
        
        
    case('ct')
    ! Mg3Si2O5(OH)4 + 6 H+ = H2O + 2 H4SiO4 + 3 Mg+2
        omega = ( &
            & mgx**3d0/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox)**3d0 &
            & *six**2d0/(1d0+k1si/prox+k2si/prox**2d0)**2d0  &
            & /prox**6d0 &
            & /keqct &
            & )
            
            
        select case(trim(adjustl(sp_name)))
            case('pro')
                ! ph dependence of mg and si are from above
                domega_dmsp = ( & 
                    & mgx**3d0*(-3d0)/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox)**4d0 &
                    & *(k1mg*(-1d0)/prox**2d0+k1mgco3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0 &
                                                                            & +k1mghco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0) &
                    & *six**2d0/(1d0+k1si/prox+k2si/prox**2d0)**2d0  &
                    & /prox**6d0 &
                    & /keqct &
                    ! 
                    & +mgx**3d0/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox)**3d0 &
                    & *six**2d0*(-2d0)/(1d0+k1si/prox+k2si/prox**2d0)**3d0  &
                    & *(k1si*(-1d0)/prox**2d0+k2si*(-2d0)/prox**3d0) &
                    & /prox**6d0 &
                    & /keqct &
                    ! 
                    & +mgx**3d0/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox)**3d0 &
                    & *six**2d0/(1d0+k1si/prox+k2si/prox**2d0)**2d0  &
                    & *(-6d0)/prox**7d0 &
                    & /keqct &
                    & )
            case('pco2')
                ! pco2 dependence of mg is from fo case
                domega_dmsp = ( & 
                    & mgx**3d0*(-3d0)/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox)**4d0 &
                    & *(k1mgco3*k1*k2*kco2*1d0/prox**2d0+k1mghco3*k1*k2*kco2*1d0/prox) &
                    & *six**2d0/(1d0+k1si/prox+k2si/prox**2d0)**2d0  &
                    & /prox**6d0 &
                    & /keqct &
                    & )
            case('mg')
                domega_dmsp = ( & 
                    & 3d0*mgx**2d0/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox)**3d0 &
                    & *six**2d0/(1d0+k1si/prox+k2si/prox**2d0)**2d0  &
                    & /prox**6d0 &
                    & /keqct &
                    & )
            case('si')
                domega_dmsp = ( & 
                    & mgx**3d0/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox)**3d0 &
                    & *six*2d0/(1d0+k1si/prox+k2si/prox**2d0)**2d0  &
                    & /prox**6d0 &
                    & /keqct &
                    & )
            case default 
                domega_dmsp = 0d0
        endselect 
        
        
    case('cabd')
    ! Beidellit-Ca  + 7.32 H+  = 4.66 H2O  + 2.33 Al+++  + 3.67 SiO2(aq)  + .165 Ca++
        omega = ( &
            & cax**(1d0/6d0)/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox)**(1d0/6d0) &
            & *alx**(7d0/3d0)/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0)**(7d0/3d0) &
            & *six**(11d0/3d0)/(1d0+k1si/prox+k2si/prox**2d0)**(11d0/3d0) &
            & /prox**(22d0/3d0) &
            & /keqcabd &
            & )
            
        ! dependences from an case
        select case(trim(adjustl(sp_name)))
            case('pro')
                domega_dmsp = ( &          
                    & cax**(1d0/6d0)*(-1d0/6d0) &
                            &/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox)**(1d0/6d0+1d0) &
                    & *(k1ca*(-1d0)/prox**2d0+k1caco3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0 &
                                                        & +k1cahco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0) &
                    & *alx**(7d0/3d0)/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0)**(7d0/3d0) &
                    & *six**(11d0/3d0)/(1d0+k1si/prox+k2si/prox**2d0)**(11d0/3d0) &
                    & /prox**(22d0/3d0) &
                    & /keqcabd &
                    !
                    & +cax**(1d0/6d0)/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox)**(1d0/6d0) &
                    & *alx**(7d0/3d0)*(-7d0/3d0) &
                            & /(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0)**(7d0/3d0+1d0) &
                    & *(k1al*(-1d0)/prox**2d0+k2al*(-2d0)/prox**3d0+k3al*(-3d0)/prox**4d0+k4al*(-4d0)/prox**5d0) &
                    & *six**(11d0/3d0)/(1d0+k1si/prox+k2si/prox**2d0)**(11d0/3d0) &
                    & /prox**(22d0/3d0) &
                    & /keqcabd &
                    !
                    & +cax**(1d0/6d0)/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox)**(1d0/6d0) &
                    & *alx**(7d0/3d0)/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0)**(7d0/3d0) &
                    & *six**(11d0/3d0)*(-11d0/3d0)/(1d0+k1si/prox+k2si/prox**2d0)**(11d0/3d0+1d0) &
                    & *(k1si*(-1d0)/prox**2d0+k2si*(-2d0)/prox**3d0) &
                    & /prox**(22d0/3d0) &
                    & /keqcabd &
                    !
                    & +cax**(1d0/6d0)/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox)**(1d0/6d0) &
                    & *alx**(7d0/3d0)/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0)**(7d0/3d0) &
                    & *six**(11d0/3d0)/(1d0+k1si/prox+k2si/prox**2d0)**(11d0/3d0) &
                    & *(-22d0/3d0)/prox**(22d0/3d0-1d0) &
                    & /keqcabd &
                    & )
            case('pco2')
                domega_dmsp = ( & 
                    & cax**(1d0/6d0)*(-1d0/6d0) &
                            & /(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox)**(1d0/6d0+1d0) &
                    & *(k1caco3*k1*k2*kco2*1d0/prox**2d0+k1cahco3*k1*k2*kco2*1d0/prox) &
                    & *alx**(7d0/3d0)/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0)**(7d0/3d0) &
                    & *six**(11d0/3d0)/(1d0+k1si/prox+k2si/prox**2d0)**(11d0/3d0) &
                    & /prox**(22d0/3d0) &
                    & /keqcabd &
                    & )
            case('ca')
                domega_dmsp = ( & 
                    & (1d0/6d0)*cax**(1d0/6d0-1d0) &
                            & /(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox)**(1d0/6d0) &
                    & *alx**(7d0/3d0)/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0)**(7d0/3d0) &
                    & *six**(11d0/3d0)/(1d0+k1si/prox+k2si/prox**2d0)**(11d0/3d0) &
                    & /prox**(22d0/3d0) &
                    & /keqcabd &
                    & )
            case('al')
                domega_dmsp = ( & 
                    & cax**(1d0/6d0)/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox)**(1d0/6d0) &
                    & *(7d0/3d0)*alx**(7d0/3d0-1d0)/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0)**(7d0/3d0) &
                    & *six**(11d0/3d0)/(1d0+k1si/prox+k2si/prox**2d0)**(11d0/3d0) &
                    & /prox**(22d0/3d0) &
                    & /keqcabd &
                    & )
            case('si')
                domega_dmsp = ( & 
                    & cax**(1d0/6d0)/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox)**(1d0/6d0) &
                    & *alx**(7d0/3d0)/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0)**(7d0/3d0) &
                    & *(11d0/3d0)*six**(11d0/3d0-1d0)/(1d0+k1si/prox+k2si/prox**2d0)**(11d0/3d0) &
                    & /prox**(22d0/3d0) &
                    & /keqcabd &
                    & )
            case default 
                domega_dmsp = 0d0
        endselect 
        
        
    case('dp')
    ! Diopside  + 4 H+  = Ca++  + 2 H2O  + Mg++  + 2 SiO2(aq)
        omega = ( &
            & cax/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox) &
            & *mgx/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox) &
            & *six**(2d0)/(1d0+k1si/prox+k2si/prox**2d0)**(2d0) &
            & /prox**(4d0) &
            & /keqdp &
            & )
            
        ! dependences from an case
        select case(trim(adjustl(sp_name)))
            case('pro')
                domega_dmsp = ( &   
                    & cax*(-1d0)/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox)**2d0 &
                    & *(k1ca*(-1d0)/prox**2d0+k1caco3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0 &
                                                        & +k1cahco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0) &
                    & *mgx/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox) &
                    & *six**(2d0)/(1d0+k1si/prox+k2si/prox**2d0)**(2d0) &
                    & /prox**(4d0) &
                    & /keqdp &
                    !
                    & +cax/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox) &
                    & *mgx*(-1d0)/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox)**2d0 &
                    & *(k1mg*(-1d0)/prox**2d0+k1mgco3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0 &
                                                        & +k1mghco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0) &
                    & *six**(2d0)/(1d0+k1si/prox+k2si/prox**2d0)**(2d0) &
                    & /prox**(4d0) &
                    & /keqdp &
                    !
                    & +cax/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox) &
                    & *mgx/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox) &
                    & *six**(2d0)*(-2d0)/(1d0+k1si/prox+k2si/prox**2d0)**(3d0) &
                    & *(k1si*(-1d0)/prox**2d0+k2si*(-2d0)/prox**3d0) &
                    & /prox**(4d0) &
                    & /keqdp &
                    !
                    & +cax/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox) &
                    & *mgx/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox) &
                    & *six**(2d0)/(1d0+k1si/prox+k2si/prox**2d0)**(2d0) &
                    & *(-4d0)/prox**(5d0) &
                    & /keqdp &
                    & )
            case('pco2')
                domega_dmsp = ( & 
                    & cax*(-1d0)/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox)**2d0 &
                    & *(k1caco3*k1*k2*kco2*1d0/prox**2d0+k1cahco3*k1*k2*kco2*1d0/prox) &
                    & *mgx/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox) &
                    & *six**(2d0)/(1d0+k1si/prox+k2si/prox**2d0)**(2d0) &
                    & /prox**(4d0) &
                    & /keqdp &
                    !
                    & +cax/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox) &
                    & *mgx*(-1d0)/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox)**2d0 &
                    & *(k1mgco3*k1*k2*kco2*1d0/prox**2d0+k1mghco3*k1*k2*kco2*1d0/prox) &
                    & *six**(2d0)/(1d0+k1si/prox+k2si/prox**2d0)**(2d0) &
                    & /prox**(4d0) &
                    & /keqdp &
                    & )
            case('mg')
                domega_dmsp = ( & 
                    & cax/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox) &
                    & *1d0/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox) &
                    & *six**(2d0)/(1d0+k1si/prox+k2si/prox**2d0)**(2d0) &
                    & /prox**(4d0) &
                    & /keqdp &
                    & )
            case('ca')
                domega_dmsp = ( & 
                    & 1d0/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox) &
                    & *mgx/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox) &
                    & *six**(2d0)/(1d0+k1si/prox+k2si/prox**2d0)**(2d0) &
                    & /prox**(4d0) &
                    & /keqdp &
                    & )
            case('si')
                domega_dmsp = ( & 
                    & cax/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox) &
                    & *mgx/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox) &
                    & *six*(2d0)/(1d0+k1si/prox+k2si/prox**2d0)**(2d0) &
                    & /prox**(4d0) &
                    & /keqdp &
                    & )
            case default 
                domega_dmsp = 0d0
        endselect 
        
        
    case('hb')
    ! Hedenbergite  + 4 H+  = 2 H2O  + 2 SiO2(aq)  + Fe++  + Ca++
        omega = &
            & cax/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox) &
            & *fe2x/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox) &
            & *six**(2d0)/(1d0+k1si/prox+k2si/prox**2d0)**(2d0) &
            & /prox**(4d0)/keqhb
            
        ! copied and pasted from dp case with replacing mg and dp by fe2 and hb
        select case(trim(adjustl(sp_name)))
            case('pro')
                domega_dmsp = ( &   
                    & cax*(-1d0)/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox)**2d0 &
                    & *(k1ca*(-1d0)/prox**2d0+k1caco3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0 &
                                                        & +k1cahco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0) &
                    & *fe2x/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox) &
                    & *six**(2d0)/(1d0+k1si/prox+k2si/prox**2d0)**(2d0) &
                    & /prox**(4d0) &
                    & /keqdp &
                    !
                    & +cax/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox) &
                    & *fe2x*(-1d0)/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox)**2d0 &
                    & *(k1fe2*(-1d0)/prox**2d0+k1fe2co3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0 &
                                                        & +k1fe2hco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0) &
                    & *six**(2d0)/(1d0+k1si/prox+k2si/prox**2d0)**(2d0) &
                    & /prox**(4d0) &
                    & /keqdp &
                    !
                    & +cax/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox) &
                    & *fe2x/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox) &
                    & *six**(2d0)*(-2d0)/(1d0+k1si/prox+k2si/prox**2d0)**(3d0) &
                    & *(k1si*(-1d0)/prox**2d0+k2si*(-2d0)/prox**3d0) &
                    & /prox**(4d0) &
                    & /keqdp &
                    !
                    & +cax/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox) &
                    & *fe2x/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox) &
                    & *six**(2d0)/(1d0+k1si/prox+k2si/prox**2d0)**(2d0) &
                    & *(-4d0)/prox**(5d0) &
                    & /keqdp &
                    & )
            case('pco2')
                domega_dmsp = ( & 
                    & cax*(-1d0)/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox)**2d0 &
                    & *(k1caco3*k1*k2*kco2*1d0/prox**2d0+k1cahco3*k1*k2*kco2*1d0/prox) &
                    & *fe2x/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox) &
                    & *six**(2d0)/(1d0+k1si/prox+k2si/prox**2d0)**(2d0) &
                    & /prox**(4d0) &
                    & /keqdp &
                    !
                    & +cax/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox) &
                    & *fe2x*(-1d0)/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox)**2d0 &
                    & *(k1fe2co3*k1*k2*kco2*1d0/prox**2d0+k1fe2hco3*k1*k2*kco2*1d0/prox) &
                    & *six**(2d0)/(1d0+k1si/prox+k2si/prox**2d0)**(2d0) &
                    & /prox**(4d0) &
                    & /keqdp &
                    & )
            case('fe2')
                domega_dmsp = ( & 
                    & cax/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox) &
                    & *1d0/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox) &
                    & *six**(2d0)/(1d0+k1si/prox+k2si/prox**2d0)**(2d0) &
                    & /prox**(4d0) &
                    & /keqdp &
                    & )
            case('ca')
                domega_dmsp = ( & 
                    & 1d0/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox) &
                    & *fe2x/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox) &
                    & *six**(2d0)/(1d0+k1si/prox+k2si/prox**2d0)**(2d0) &
                    & /prox**(4d0) &
                    & /keqdp &
                    & )
            case('si')
                domega_dmsp = ( & 
                    & cax/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox) &
                    & *fe2x/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox) &
                    & *six*(2d0)/(1d0+k1si/prox+k2si/prox**2d0)**(2d0) &
                    & /prox**(4d0) &
                    & /keqdp &
                    & )
            case default 
                domega_dmsp = 0d0
        endselect 
        
        
    case('py')
    ! omega is defined so that kpy*poro*hr*mvpy*1d-6*mpyx*(1d0-omega_py) = kpy*poro*hr*mvpy*1d-6*mpyx*po2x**0.5d0
    ! i.e., 1.0 - omega_py = po2x**0.5 
        ! omega = 1d0 - po2x**0.5d0
        omega = 1d0 - po2x**0.5d0*merge(0d0,1d0,po2x<po2th)
        ! omega = merge(1d0,1d0 - po2x**0.5d0,po2x<po2th.or. isnan(po2x**0.5d0) .or. isnan(po2x**(-0.5d0)))
        ! omega = 0d0
        
        select case(trim(adjustl(sp_name)))
            case('po2')
                domega_dmsp = ( &
                    & - 0.5d0/po2x**(0.5d0)*merge(0d0,1d0,po2x<po2th) &
                    & )
                ! domega_dmsp = merge(0d0,-0.5d0*po2x**(-0.5d0),po2x<po2th.or. isnan(po2x**0.5d0) .or. isnan(po2x**(-0.5d0)))
            case default 
                domega_dmsp = 0d0
        endselect 
        
    case('om')
    ! omega is defined so that kpy*poro*hr*mvpy*1d-6*mpyx*(1d0-omega_py) = kpy*poro*hr*mvpy*1d-6*mpyx*po2x**0.5d0
    ! i.e., 1.0 - omega_py = po2x**0.5 
        ! omega = 1d0 - po2x**0.5d0
        omega = 1d0 
        domega_dmsp = 0d0
        ! omega = 0d0
        
    case('omb')
    ! omega is defined so that kpy*poro*hr*mvpy*1d-6*mpyx*(1d0-omega_py) = kpy*poro*hr*mvpy*1d-6*mpyx*po2x**0.5d0
    ! i.e., 1.0 - omega_py = po2x**0.5 
        ! omega = 1d0 - po2x**0.5d0
        omega = 1d0 
        domega_dmsp = 0d0
        ! omega = 0d0
        
        
    case('g1')
    ! omega is defined so that kg1*poro*hr*mvg1*1d-6*mg1x*(1d0-omega_g1) = kg1*poro*hr*mvg1*1d-6*mg1x*po2x/(po2x+mo2)
    ! i.e., 1.0 - omega_g1 = po2x/(po2x+mo2) 
        omega = 1d0 
        domega_dmsp = 0d0
        ! print *,mineral,sp_name
        ! omega = 1d0 - po2x/(po2x+mo2)
        
        
        
        ! omega = 1d0 - po2x/(po2x + keqg1)
        
        ! select case(trim(adjustl(sp_name)))
            ! case('po2')
                ! domega_dmsp = ( &
                    ! & - 1d0/(po2x + keqg1) &
                    ! & - po2x*(-1d0)/(po2x + keqg1)**2d0 &
                    ! & )
            ! case default 
                ! domega_dmsp = 0d0
        ! endselect 
        
        ! print*, omega
        
        
    case('g2')
    ! omega is defined so that kg2*poro*hr*mvg2*1d-6*mg2x*(1d0-omega_g2) = kg2*poro*hr*mvg2*1d-6*mg2x*po2x/(po2x+mo2)
    ! i.e., 1.0 - omega_g2 = po2x/(po2x+mo2) 
        ! omega = 1d0 - po2x/(po2x+mo2)
        ! print *,mineral,sp_name
        
        
        omega = 1d0 
        domega_dmsp = 0d0
        
        ! omega = 1d0 - po2x/(po2x + keqg2)
        
        ! select case(trim(adjustl(sp_name)))
            ! case('po2')
                ! domega_dmsp = ( &
                    ! & - 1d0/(po2x + keqg2) &
                    ! & - po2x*(-1d0)/(po2x + keqg2)**2d0 &
                    ! & )
            ! case default 
                ! domega_dmsp = 0d0
        ! endselect 
        
        ! print*, omega
        
        
    case('g3')
    ! omega is defined so that kg3*poro*hr*mvg3*1d-6*mg3x*(1d0-omega_g3) = kg3*poro*hr*mvg3*1d-6*mg3x*po2x/(po2x+mo2)
    ! i.e., 1.0 - omega_g3 = po2x/(po2x+mo2) 
        ! omega = 1d0 - po2x/(po2x+mo2)
        ! print *,mineral,sp_name
        omega = 1d0 
        domega_dmsp = 0d0
        
        ! omega = 1d0 - po2x/(po2x + keqg3)
        
        ! select case(trim(adjustl(sp_name)))
            ! case('po2')
                ! domega_dmsp = ( &
                    ! & - 1d0/(po2x + keqg3) &
                    ! & - po2x*(-1d0)/(po2x + keqg3)**2d0 &
                    ! & )
            ! case default 
                ! domega_dmsp = 0d0
        ! endselect 
        
        ! print*, omega
        
        
    case default 
        ! print *,'non-specified'
        omega = 1d0
        domega_dmsp = 0d0
        ! print *,omega
        
endselect

omega_error = .false.
if (any(isnan(omega)) .or. any(isnan(domega_dmsp))) then 
    print *,'nan in calc_omega_dev',any(isnan(omega)),any(isnan(domega_dmsp)),mineral,sp_name
    omega_error = .true.
    ! stop
endif 

endsubroutine calc_omega_dev

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine calc_omega_dev_v2( &
    & nz,nsp_aq,nsp_gas,nsp_aq_all,nsp_sld_all,nsp_gas_all,nsp_aq_cnst,nsp_gas_cnst &! input 
    & ,chraq,chraq_cnst,chraq_all,chrsld_all,chrgas,chrgas_cnst,chrgas_all &!input
    & ,maqx,maqc,mgasx,mgasc,keqgas_h,keqaq_h,keqaq_c,keqsld_all,mgasth_all,keqaq_s,so4f,staq_all &! input
    & ,prox,mineral,sp_name &! input 
    & ,omega,domega_dmsp,omega_error &! output
    & )
implicit none
integer,intent(in)::nz
real(kind=8):: keqfo,keqab,keqan,keqcc,k1,k2,kco2,k1si,k2si,k1mg,k1mgco3,k1mghco3,k1ca,k1caco3,k1cahco3 &
    & ,k1al,k2al,k3al,k4al,keqka,keqgb,keqct,k1fe2,k1fe2co3,k1fe2hco3,keqfa,k1fe3,k2fe3,k3fe3,k4fe3,keqgt &
    & ,keqcabd,keqdp,keqhb,keqkfs,keqamsi,keqg1,keqg2,keqg3,po2th,k1naco3,k1nahco3,k1so4,k1kso4,k1naso4  &
    & ,k1caso4,k1mgso4,k1fe2so4,k1also4,k1also42,k1fe3so4,k1fe3so42,mo2g1,mo2g2,mo2g3,keq_tmp,ss_x
real(kind=8),dimension(nz),intent(in):: prox,so4f
real(kind=8),dimension(nz):: pco2x,cax,mgx,six,nax,alx,po2x,fe2x,fe3x,kx,so4x
real(kind=8),dimension(nz):: caf,mgf,sif,naf,alf,fe2f,fe3f,kf
real(kind=8),dimension(nz):: dcaf_dpro,dmgf_dpro,dsif_dpro,dnaf_dpro,dalf_dpro,dfe2f_dpro,dfe3f_dpro,dkf_dpro
real(kind=8),dimension(nz):: dcaf_dpco2,dmgf_dpco2,dsif_dpco2,dnaf_dpco2,dalf_dpco2,dfe2f_dpco2,dfe3f_dpco2,dkf_dpco2
real(kind=8),dimension(nz):: dcaf_dca,dmgf_dmg,dsif_dsi,dnaf_dna,dalf_dal,dfe2f_dfe2,dfe3f_dfe3,dkf_dk,dso4f_dso4,dso4f_dpro &
    & ,dso4f_dpco2,dkf_dso4f,dnaf_dso4f,dcaf_dso4f,dmgf_dso4f,dalf_dso4f,dfe2f_dso4f,dfe3f_dso4f,dsif_dso4f
real(kind=8),dimension(nz),intent(out):: domega_dmsp
real(kind=8),dimension(nz),intent(out):: omega
logical,intent(out)::omega_error
character(5),intent(in):: mineral,sp_name

integer,intent(in)::nsp_aq,nsp_gas,nsp_aq_all,nsp_gas_all,nsp_sld_all,nsp_aq_cnst,nsp_gas_cnst
character(5),dimension(nsp_aq),intent(in)::chraq
character(5),dimension(nsp_aq_cnst),intent(in)::chraq_cnst
character(5),dimension(nsp_aq_all),intent(in)::chraq_all
character(5),dimension(nsp_gas),intent(in)::chrgas
character(5),dimension(nsp_gas_cnst),intent(in)::chrgas_cnst
character(5),dimension(nsp_gas_all),intent(in)::chrgas_all
character(5),dimension(nsp_sld_all),intent(in)::chrsld_all
real(kind=8),dimension(nsp_aq,nz),intent(in)::maqx
real(kind=8),dimension(nsp_aq_cnst,nz),intent(in)::maqc
real(kind=8),dimension(nsp_gas,nz),intent(in)::mgasx
real(kind=8),dimension(nsp_gas_cnst,nz),intent(in)::mgasc
real(kind=8),dimension(nsp_gas_all),intent(in)::mgasth_all
real(kind=8),dimension(nsp_gas_all,3),intent(in)::keqgas_h
real(kind=8),dimension(nsp_aq_all,4),intent(in)::keqaq_h
real(kind=8),dimension(nsp_aq_all,2),intent(in)::keqaq_c,keqaq_s
real(kind=8),dimension(nsp_sld_all),intent(in)::keqsld_all
real(kind=8),dimension(nsp_sld_all,nsp_aq_all),intent(in)::staq_all

integer ieqgas_h0,ieqgas_h1,ieqgas_h2
data ieqgas_h0,ieqgas_h1,ieqgas_h2/1,2,3/

integer ieqaq_h1,ieqaq_h2,ieqaq_h3,ieqaq_h4
data ieqaq_h1,ieqaq_h2,ieqaq_h3,ieqaq_h4/1,2,3,4/

integer ieqaq_co3,ieqaq_hco3
data ieqaq_co3,ieqaq_hco3/1,2/

integer ieqaq_so4,ieqaq_so42
data ieqaq_so4,ieqaq_so42/1,2/

! real(kind=8)::thon = 1d0
real(kind=8)::thon = -1d100

kco2 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h0)
k1 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h1)
k2 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h2)
keqab = keqsld_all(findloc(chrsld_all,'ab',dim=1))
keqfo = keqsld_all(findloc(chrsld_all,'fo',dim=1))
keqan = keqsld_all(findloc(chrsld_all,'an',dim=1))
keqcc = keqsld_all(findloc(chrsld_all,'cc',dim=1))
k1si = keqaq_h(findloc(chraq_all,'si',dim=1),ieqaq_h1)
k2si = keqaq_h(findloc(chraq_all,'si',dim=1),ieqaq_h2)
k1mg = keqaq_h(findloc(chraq_all,'mg',dim=1),ieqaq_h1)
k1mgco3 = keqaq_c(findloc(chraq_all,'mg',dim=1),ieqaq_co3)
k1mghco3  = keqaq_c(findloc(chraq_all,'mg',dim=1),ieqaq_hco3)
k1ca = keqaq_h(findloc(chraq_all,'ca',dim=1),ieqaq_h1)
k1caco3 = keqaq_c(findloc(chraq_all,'ca',dim=1),ieqaq_co3)
k1cahco3 = keqaq_c(findloc(chraq_all,'ca',dim=1),ieqaq_hco3)
k1al= keqaq_h(findloc(chraq_all,'al',dim=1),ieqaq_h1)
k2al= keqaq_h(findloc(chraq_all,'al',dim=1),ieqaq_h2)
k3al= keqaq_h(findloc(chraq_all,'al',dim=1),ieqaq_h3)
k4al= keqaq_h(findloc(chraq_all,'al',dim=1),ieqaq_h4)
keqka = keqsld_all(findloc(chrsld_all,'ka',dim=1))
keqgb =  keqsld_all(findloc(chrsld_all,'gb',dim=1))
keqct =  keqsld_all(findloc(chrsld_all,'ct',dim=1))
k1fe2 = keqaq_h(findloc(chraq_all,'fe2',dim=1),ieqaq_h1)
k1fe2co3 = keqaq_c(findloc(chraq_all,'fe2',dim=1),ieqaq_co3)
k1fe2hco3  = keqaq_c(findloc(chraq_all,'fe2',dim=1),ieqaq_hco3)
keqfa = keqsld_all(findloc(chrsld_all,'fa',dim=1))
k1fe3= keqaq_h(findloc(chraq_all,'fe3',dim=1),ieqaq_h1)
k2fe3= keqaq_h(findloc(chraq_all,'fe3',dim=1),ieqaq_h2)
k3fe3= keqaq_h(findloc(chraq_all,'fe3',dim=1),ieqaq_h3)
k4fe3= keqaq_h(findloc(chraq_all,'fe3',dim=1),ieqaq_h4)
keqgt = keqsld_all(findloc(chrsld_all,'gt',dim=1))
keqcabd = keqsld_all(findloc(chrsld_all,'cabd',dim=1))
keqdp = keqsld_all(findloc(chrsld_all,'dp',dim=1))
keqhb = keqsld_all(findloc(chrsld_all,'hb',dim=1))
keqkfs = keqsld_all(findloc(chrsld_all,'kfs',dim=1))
keqamsi = keqsld_all(findloc(chrsld_all,'amsi',dim=1))
keqg1 = keqsld_all(findloc(chrsld_all,'g1',dim=1))
keqg2 = keqsld_all(findloc(chrsld_all,'g2',dim=1))
keqg3 = keqsld_all(findloc(chrsld_all,'g3',dim=1))
k1naco3 = keqaq_c(findloc(chraq_all,'na',dim=1),ieqaq_co3)
k1nahco3 = keqaq_c(findloc(chraq_all,'na',dim=1),ieqaq_hco3)

k1so4 = keqaq_h(findloc(chraq_all,'so4',dim=1),ieqaq_h1)
k1naso4 = keqaq_s(findloc(chraq_all,'na',dim=1),ieqaq_so4)
k1kso4 = keqaq_s(findloc(chraq_all,'k',dim=1),ieqaq_so4)
k1caso4 = keqaq_s(findloc(chraq_all,'ca',dim=1),ieqaq_so4)
k1mgso4 = keqaq_s(findloc(chraq_all,'mg',dim=1),ieqaq_so4)
k1fe2so4 = keqaq_s(findloc(chraq_all,'fe2',dim=1),ieqaq_so4)
k1also4 = keqaq_s(findloc(chraq_all,'al',dim=1),ieqaq_so4)
k1fe3so4 = keqaq_s(findloc(chraq_all,'fe3',dim=1),ieqaq_so4)
k1also42 = keqaq_s(findloc(chraq_all,'al',dim=1),ieqaq_so42)
k1fe3so42 = keqaq_s(findloc(chraq_all,'fe3',dim=1),ieqaq_so42)

mo2g1 = keqsld_all(findloc(chrsld_all,'g1',dim=1))
mo2g2 = keqsld_all(findloc(chrsld_all,'g2',dim=1))
mo2g3 = keqsld_all(findloc(chrsld_all,'g3',dim=1))

po2th = mgasth_all(findloc(chrgas_all,'po2',dim=1))


nax = 0d0
kx = 0d0

if (any(chraq=='na')) then 
    nax = maqx(findloc(chraq,'na',dim=1),:)
elseif (any(chraq_cnst=='na')) then 
    nax = maqc(findloc(chraq_cnst,'na',dim=1),:)
endif 
if (any(chraq=='k')) then 
    kx = maqx(findloc(chraq,'k',dim=1),:)
elseif (any(chraq_cnst=='k')) then 
    kx = maqc(findloc(chraq_cnst,'k',dim=1),:)
endif 

six =0d0
cax =0d0
mgx =0d0
fe2x =0d0
fe3x =0d0
alx =0d0
pco2x =0d0
so4x = 0d0

if (any(chraq=='si')) then 
    six = maqx(findloc(chraq,'si',dim=1),:)
elseif (any(chraq_cnst=='si')) then 
    six = maqc(findloc(chraq_cnst,'si',dim=1),:)
endif 
if (any(chraq=='ca')) then 
    cax = maqx(findloc(chraq,'ca',dim=1),:)
elseif (any(chraq_cnst=='ca')) then 
    cax = maqc(findloc(chraq_cnst,'ca',dim=1),:)
endif 
if (any(chraq=='mg')) then 
    mgx = maqx(findloc(chraq,'mg',dim=1),:)
elseif (any(chraq_cnst=='mg')) then 
    mgx = maqc(findloc(chraq_cnst,'mg',dim=1),:)
endif 
if (any(chraq=='fe2')) then 
    fe2x = maqx(findloc(chraq,'fe2',dim=1),:)
elseif (any(chraq_cnst=='fe2')) then 
    fe2x = maqc(findloc(chraq_cnst,'fe2',dim=1),:)
endif 
if (any(chraq=='al')) then 
    alx = maqx(findloc(chraq,'al',dim=1),:)
elseif (any(chraq_cnst=='al')) then 
    alx = maqc(findloc(chraq_cnst,'al',dim=1),:)
endif 
if (any(chraq=='fe3')) then 
    fe3x = maqx(findloc(chraq,'fe3',dim=1),:)
elseif (any(chraq_cnst=='fe3')) then 
    fe3x = maqc(findloc(chraq_cnst,'fe3',dim=1),:)
endif 
if (any(chraq=='so4')) then 
    so4x = maqx(findloc(chraq,'so4',dim=1),:)
elseif (any(chraq_cnst=='so4')) then 
    so4x = maqc(findloc(chraq_cnst,'so4',dim=1),:)
endif 
if (any(chrgas=='pco2')) then 
    pco2x = mgasx(findloc(chrgas,'pco2',dim=1),:)
elseif (any(chrgas_cnst=='pco2')) then 
    pco2x = mgasc(findloc(chrgas_cnst,'pco2',dim=1),:)
endif 
if (any(chrgas=='po2')) then 
    po2x = mgasx(findloc(chrgas,'po2',dim=1),:)
elseif (any(chrgas_cnst=='po2')) then 
    po2x = mgasc(findloc(chrgas_cnst,'po2',dim=1),:)
endif 


    
kf = kx/(1d0+k1kso4*so4f)
dkf_dk = 1d0/(1d0+k1kso4*so4f)
dkf_dpro = 0d0
dkf_dpco2 = 0d0
dkf_dso4f = kx*(-1d0)/(1d0+k1kso4*so4f)**2d0 *k1kso4

naf = nax/(1d0+k1naco3*k1*k2*kco2*pco2x/prox**2d0+k1nahco3*k1*k2*kco2*pco2x/prox+k1naso4*so4f)
dnaf_dna = 1d0/(1d0+k1naco3*k1*k2*kco2*pco2x/prox**2d0+k1nahco3*k1*k2*kco2*pco2x/prox+k1naso4*so4f)
dnaf_dpro = nax*(-1d0)/(1d0+k1naco3*k1*k2*kco2*pco2x/prox**2d0+k1nahco3*k1*k2*kco2*pco2x/prox+k1naso4*so4f)**2d0 &
    & *(k1naco3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0+k1nahco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0)
dnaf_dpco2 = nax*(-1d0)/(1d0+k1naco3*k1*k2*kco2*pco2x/prox**2d0+k1nahco3*k1*k2*kco2*pco2x/prox+k1naso4*so4f)**2d0 &
    & *(k1naco3*k1*k2*kco2*1d0/prox**2d0+k1nahco3*k1*k2*kco2*1d0/prox)
dnaf_dso4f = nax*(-1d0)/(1d0+k1naco3*k1*k2*kco2*pco2x/prox**2d0+k1nahco3*k1*k2*kco2*pco2x/prox+k1naso4*so4f)**2d0 &
    & * k1naso4
    
caf = cax/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox+k1caso4*so4f)
dcaf_dca = 1d0/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox+k1caso4*so4f)
dcaf_dpro = cax*(-1d0)/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox+k1caso4*so4f)**2d0 &
    & *(k1ca*(-1d0)/prox**2d0+k1caco3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0+k1cahco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0)
dcaf_dpco2 = cax*(-1d0)/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox+k1caso4*so4f)**2d0 &
    & *(k1caco3*k1*k2*kco2*1d0/prox**2d0+k1cahco3*k1*k2*kco2*1d0/prox)
dcaf_dso4f = cax*(-1d0)/(1d0+k1ca/prox+k1caco3*k1*k2*kco2*pco2x/prox**2d0+k1cahco3*k1*k2*kco2*pco2x/prox+k1caso4*so4f)**2d0 &
    & * k1caso4
    
mgf = mgx/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox+k1mgso4*so4f)
dmgf_dmg = 1d0/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox+k1mgso4*so4f)
dmgf_dpro = mgx*(-1d0)/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox+k1mgso4*so4f)**2d0 &
    & *(k1mg*(-1d0)/prox**2d0+k1mgco3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0+k1mghco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0)
dmgf_dpco2 = mgx*(-1d0)/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox+k1mgso4*so4f)**2d0 &
    & *(k1mgco3*k1*k2*kco2*1d0/prox**2d0+k1mghco3*k1*k2*kco2*1d0/prox)
dmgf_dso4f = mgx*(-1d0)/(1d0+k1mg/prox+k1mgco3*k1*k2*kco2*pco2x/prox**2d0+k1mghco3*k1*k2*kco2*pco2x/prox+k1mgso4*so4f)**2d0 &
    & * k1mgso4
    
fe2f = fe2x/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox+k1fe2so4*so4f)
dfe2f_dfe2 = 1d0/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox+k1fe2so4*so4f)
dfe2f_dpro = fe2x*(-1d0) &
    & /(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox+k1fe2so4*so4f)**2d0 &
    & *(k1fe2*(-1d0)/prox**2d0+k1fe2co3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0+k1fe2hco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0)
dfe2f_dpco2 = fe2x*(-1d0) &
    & /(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox+k1fe2so4*so4f)**2d0 &
    & *(k1fe2co3*k1*k2*kco2*1d0/prox**2d0+k1fe2hco3*k1*k2*kco2*1d0/prox)
dfe2f_dso4f = fe2x*(-1d0) &
    & /(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox+k1fe2so4*so4f)**2d0 &
    & * k1fe2so4
    
sif = six/(1d0+k1si/prox+k2si/prox**2d0)
dsif_dsi = 1d0/(1d0+k1si/prox+k2si/prox**2d0)
dsif_dpro = six*(-1d0)/(k1si*(-1d0)/prox**2d0+k2si*(-2d0)/prox**3d0)
dsif_dpco2 = 0d0
dsif_dso4f = 0d0

alf = alx/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0+k1also4*so4f)
dalf_dal = 1d0/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0+k1also4*so4f)
dalf_dpro = alx*(-1d0)/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0+k1also4*so4f)**2d0 &
    & *(k1al*(-1d0)/prox**2d0+k2al*(-2d0)/prox**3d0+k3al*(-3d0)/prox**4d0+k4al*(-4d0)/prox**5d0)
dalf_dpco2 = 0d0
dalf_dso4f = alx*(-1d0)/(1d0+k1al/prox+k2al/prox**2d0+k3al/prox**3d0+k4al/prox**4d0+k1also4*so4f)**2d0 & 
    & * k1also4

fe3f = fe3x/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0+k1fe3so4*so4f)
dfe3f_dfe3 = 1d0/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0+k1fe3so4*so4f)
dfe3f_dpro = fe3x*(-1d0)/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0+k1fe3so4*so4f)**2d0 &
    & *(k1fe3*(-1d0)/prox**2d0+k2fe3*(-2d0)/prox**3d0+k3fe3*(-3d0)/prox**4d0+k4fe3*(-4d0)/prox**5d0)
dfe3f_dpco2 = 0d0
dfe3f_dso4f = fe3x*(-1d0)/(1d0+k1fe3/prox+k2fe3/prox**2d0+k3fe3/prox**3d0+k4fe3/prox**4d0+k1fe3so4*so4f)**2d0 &
    & * k1fe3so4

dso4f_dso4 = 1d0/( 1d0+k1so4/prox &
        & +k1kso4*kf &
        & +k1naso4*naf &
        & +k1caso4*caf &
        & +k1mgso4*mgf &
        & +k1fe2so4*fe2f &
        & +k1also4*alf &
        & +k1fe3so4*fe3f &
        & )

dso4f_dpro = so4x*(-1d0)/( 1d0+k1so4/prox &
        & +k1kso4*kf &
        & +k1naso4*naf &
        & +k1caso4*caf &
        & +k1mgso4*mgf &
        & +k1fe2so4*fe2f &
        & +k1also4*alf &
        & +k1fe3so4*fe3f &
        & )**2d0 &
        & * (k1so4*(-1d0)/prox**2d0 &
        & )
! dso4f_dpro = 0d0
dso4f_dpco2 = 0d0

select case(trim(adjustl(mineral)))
    case('fo')
    ! Fo + 4H+ = 2Mg2+ + SiO2(aq) + 2H2O 
        omega = ( & 
            & mgf**2d0 &
            & *sif &
            & /prox**4d0 &
            & /keqfo &
            & )
        select case(trim(adjustl(sp_name)))
            case('pro')
                domega_dmsp = ( & 
                    & mgf*2d0*dmgf_dpro &
                    & *sif &
                    & /prox**4d0 &
                    & /keqfo &
                    !
                    & +mgf**2d0 &
                    & *dsif_dpro &
                    & /prox**4d0 &
                    & /keqfo &
                    !
                    & +mgf**2d0 &
                    & *sif &
                    & *(-4d0)/prox**5d0 &
                    & /keqfo &
                    & )
            case('so4f')
                domega_dmsp = ( & 
                    & mgf*2d0*dmgf_dso4f &
                    & *sif &
                    & /prox**4d0 &
                    & /keqfo &
                    !
                    & +mgf**2d0 &
                    & *dsif_dso4f &
                    & /prox**4d0 &
                    & /keqfo &
                    & )
            case('mg')
                domega_dmsp = ( & 
                    & mgf*2d0*dmgf_dmg &
                    & *sif &
                    & /prox**4d0 &
                    & /keqfo &
                    & )
            case('si')
                domega_dmsp = ( & 
                    & mgf**2d0 &
                    & *dsif_dsi &
                    & /prox**4d0 &
                    & /keqfo &
                    & )
            case('pco2')
                domega_dmsp = ( & 
                    & mgf*2d0*dmgf_dpco2 &
                    & *sif &
                    & /prox**4d0 &
                    & /keqfo &
                    & )
            case default 
                domega_dmsp = 0d0
        endselect 
        
    case('fa')
    ! Fa + 4H+ = 2Fe2+ + SiO2(aq) + 2H2O 
        omega = ( & 
            & fe2f**2d0 &
            & *sif &
            & /prox**4d0 &
            & /keqfa &
            & )
            
        select case(trim(adjustl(sp_name)))
            case('pro')
                domega_dmsp = ( & 
                    & fe2f*2d0*dfe2f_dpro &
                    & *sif &
                    & /prox**4d0 &
                    & /keqfa &
                    !
                    & +fe2f**2d0 &
                    & *dsif_dpro &
                    & /prox**4d0 &
                    & /keqfa &
                    !
                    & +fe2f**2d0 &
                    & *sif &
                    & *(-4d0)/prox**5d0 &
                    & /keqfa &
                    & )
            case('so4f')
                domega_dmsp = ( & 
                    & fe2f*2d0*dfe2f_dso4f &
                    & *sif &
                    & /prox**4d0 &
                    & /keqfa &
                    !
                    & +fe2f**2d0 &
                    & *dsif_dso4f &
                    & /prox**4d0 &
                    & /keqfa &
                    & )
            case('fe2')
                domega_dmsp = ( & 
                    & fe2f*2d0*dfe2f_dfe2 &
                    & *sif &
                    & /prox**4d0 &
                    & /keqfa &
                    & )
            case('si')
                domega_dmsp = ( & 
                    & fe2f**2d0 &
                    & *1d0*dsif_dsi &
                    & /prox**4d0 &
                    & /keqfa &
                    & )
            case('pco2')
                domega_dmsp = ( & 
                    & fe2f*2d0*dfe2f_dpco2 &
                    & *sif &
                    & /prox**4d0 &
                    & /keqfa &
                    & )
            case default 
                domega_dmsp = 0d0
        endselect 
        
    case('ab')
    ! NaAlSi3O8 + 4 H+ = Na+ + Al3+ + 3SiO2 + 2H2O
        omega = ( & 
            & naf & 
            & *alf &
            & *sif**3d0 &
            & /prox**4d0 &
            & /keqab &
            & )
            
        select case(trim(adjustl(sp_name)))
            case('pro')
                domega_dmsp = ( & 
                    & 1d0*dnaf_dpro & 
                    & *alf &
                    & *sif**3d0 &
                    & /prox**4d0 &
                    & /keqab &
                    
                    & +naf & 
                    & *1d0*dalf_dpro &
                    & *sif**3d0 &
                    & /prox**4d0 &
                    & /keqab &
                    
                    & +naf & 
                    & *alf &
                    & *3d0*sif**2d0*dsif_dpro &
                    & /prox**4d0 &
                    & /keqab &
                    
                    & +naf & 
                    & *alf &
                    & *sif**3d0 &
                    & *(-4d0)/prox**5d0 &
                    & /keqab &
                    & )
            case('so4f')
                domega_dmsp = ( & 
                    & 1d0*dnaf_dso4f & 
                    & *alf &
                    & *sif**3d0 &
                    & /prox**4d0 &
                    & /keqab &
                    
                    & +naf & 
                    & *1d0*dalf_dso4f &
                    & *sif**3d0 &
                    & /prox**4d0 &
                    & /keqab &
                    
                    & +naf & 
                    & *alf &
                    & *3d0*sif**2d0*dsif_dso4f &
                    & /prox**4d0 &
                    & /keqab &
                    & )
            case('na')
                domega_dmsp = ( & 
                    & 1d0*dnaf_dna & 
                    & *alf &
                    & *sif**3d0 &
                    & /prox**4d0 &
                    & /keqab &
                    & )
            case('al')
                domega_dmsp = ( & 
                    & naf & 
                    & *1d0*dalf_dal &
                    & *sif**3d0 &
                    & /prox**4d0 &
                    & /keqab &
                    & )
            case('si')
                domega_dmsp = ( & 
                    & naf & 
                    & *alf &
                    & *3d0*sif**2d0*dsif_dsi &
                    & /prox**4d0 &
                    & /keqab &
                    & )
            case('pco2')
                domega_dmsp = ( & 
                    & 1d0*dnaf_dpco2 & 
                    & *alf &
                    & *sif**3d0 &
                    & /prox**4d0 &
                    & /keqab &
                    & )
            case default 
                domega_dmsp = 0d0
        endselect 
        
        
    case('kfs')
    ! K-feldspar  + 4 H+  = 2 H2O  + K+  + Al+++  + 3 SiO2(aq)
        omega = ( & 
            & kf &
            & *alf &
            & *sif**3d0 &
            & /prox**4d0 &
            & /keqkfs   &
            & )
            
        select case(trim(adjustl(sp_name)))
            case('pro')
                domega_dmsp = ( & 
                    & 1d0*dkf_dpro &
                    & *alf &
                    & *sif**3d0 &
                    & /prox**4d0 &
                    & /keqkfs   &
                    ! 
                    & +kf &
                    & *1d0*dalf_dpro &
                    & *sif**3d0 &
                    & /prox**4d0 &
                    & /keqkfs   &
                    ! 
                    & +kf &
                    & *alf &
                    & *3d0*sif**2d0*dsif_dpro &
                    & /prox**4d0 &
                    & /keqkfs   &
                    !
                    & +kf &
                    & *alf &
                    & *sif**3d0 &
                    & *(-4d0)/prox**5d0 &
                    & /keqkfs   &
                    & )
            case('so4f')
                domega_dmsp = ( & 
                    & 1d0*dkf_dso4f &
                    & *alf &
                    & *sif**3d0 &
                    & /prox**4d0 &
                    & /keqkfs   &
                    ! 
                    & +kf &
                    & *1d0*dalf_dso4f &
                    & *sif**3d0 &
                    & /prox**4d0 &
                    & /keqkfs   &
                    ! 
                    & +kf &
                    & *alf &
                    & *3d0*sif**2d0*dsif_dso4f &
                    & /prox**4d0 &
                    & /keqkfs   &
                    & )
            case('k')
                domega_dmsp = ( & 
                    & 1d0*dkf_dk &
                    & *alf &
                    & *sif**3d0 &
                    & /prox**4d0 &
                    & /keqkfs   &
                    & )
            case('al')
                domega_dmsp = ( & 
                    & kf &
                    & *1d0*dalf_dal &
                    & *sif**3d0 &
                    & /prox**4d0 &
                    & /keqkfs   &
                    & )
            case('si')
                domega_dmsp = ( & 
                    & kf &
                    & *alf &
                    & *3d0*sif**2d0*dsif_dsi &
                    & /prox**4d0 &
                    & /keqkfs   &
                    & )
            case default 
                domega_dmsp = 0d0
        endselect 
        
        
    case('an')
    ! CaAl2Si2O8 + 8H+ = Ca2+ + 2 Al3+ + 2SiO2 + 4H2O
        omega = ( & 
            & caf &
            & *alf**2d0 &
            & *sif**2d0 &
            & /prox**8d0 &
            & /keqan &
            & )
            
        select case(trim(adjustl(sp_name)))
            case('pro')
                domega_dmsp = ( & 
                    & 1d0*dcaf_dpro &
                    & *alf**2d0 &
                    & *sif**2d0 &
                    & /prox**8d0 &
                    & /keqan &
                    & + &
                    & caf &
                    & *alf*2d0*dalf_dpro &
                    & *sif**2d0 &
                    & /prox**8d0 &
                    & /keqan &
                    & + &
                    & caf &
                    & *alf**2d0 &
                    & *sif*2d0*dsif_dpro &
                    & /prox**8d0 &
                    & /keqan &
                    & + &
                    & caf &
                    & *alf**2d0 &
                    & *sif**2d0 &
                    & *(-8d0)/prox**9d0 &
                    & /keqan &
                    & )
            case('so4f')
                domega_dmsp = ( & 
                    & 1d0*dcaf_dso4f &
                    & *alf**2d0 &
                    & *sif**2d0 &
                    & /prox**8d0 &
                    & /keqan &
                    & + &
                    & caf &
                    & *alf*2d0*dalf_dso4f &
                    & *sif**2d0 &
                    & /prox**8d0 &
                    & /keqan &
                    & + &
                    & caf &
                    & *alf**2d0 &
                    & *sif*2d0*dsif_dso4f &
                    & /prox**8d0 &
                    & /keqan &
                    & )
            case('pco2')
                domega_dmsp = ( & 
                    & 1d0*dcaf_dpco2 &
                    & *alf**2d0 &
                    & *sif**2d0 &
                    & /prox**8d0 &
                    & /keqan &
                    & )
            case('ca')
                domega_dmsp = ( & 
                    & 1d0*dcaf_dca &
                    & *alf**2d0 &
                    & *sif**2d0 &
                    & /prox**8d0 &
                    & /keqan &
                    & )
            case('al')
                domega_dmsp = ( & 
                    & caf &
                    & *alf*2d0*dalf_dal &
                    & *sif**2d0 &
                    & /prox**8d0 &
                    & /keqan &
                    & )
            case('si')
                domega_dmsp = ( & 
                    & caf &
                    & *alf**2d0 &
                    & *sif*2d0*dsif_dsi &
                    & /prox**8d0 &
                    & /keqan &
                    & )
            case default 
                domega_dmsp = 0d0
        endselect 
        
        
    case('la','by','olg','and')
        ! CaxNa(1-x)Al(1+x)Si(3-x)O8 + (4x + 4) = xCa+2 + (1-x)Na+ + (1+x)Al+++ + (3-x)SiO2(aq) 
        keq_tmp = keqsld_all(findloc(chrsld_all,mineral,dim=1))
        ss_x = staq_all(findloc(chrsld_all,mineral,dim=1), findloc(chraq_all,'ca',dim=1) )
        omega = ( & 
            & caf**ss_x &
            & *naf**(1d0-ss_x) &
            & *alf**(1d0+ss_x) &
            & *sif**(3d0-ss_x) &
            & /prox**(4d0 + 4d0*ss_x) &
            & /keq_tmp &
            & )
            
        select case(trim(adjustl(sp_name)))
            case('pro')
                domega_dmsp = ( & 
                    & ss_x*caf**(ss_x-1d0)*dcaf_dpro &
                    & *naf**(1d0-ss_x) &
                    & *alf**(1d0+ss_x) &
                    & *sif**(3d0-ss_x) &
                    & /prox**(4d0 + 4d0*ss_x) &
                    & /keq_tmp &
                    & + &
                    & caf**ss_x &
                    & *(1d0-ss_x)*naf**(1d0-ss_x-1d0)*dnaf_dpro &
                    & *alf**(1d0+ss_x) &
                    & *sif**(3d0-ss_x) &
                    & /prox**(4d0 + 4d0*ss_x) &
                    & /keq_tmp &
                    & + &
                    & caf**ss_x &
                    & *naf**(1d0-ss_x) &
                    & *(1d0+ss_x)*alf**(1d0+ss_x-1d0)*dalf_dpro &
                    & *sif**(3d0-ss_x) &
                    & /prox**(4d0 + 4d0*ss_x) &
                    & /keq_tmp &
                    & + &
                    & caf**ss_x &
                    & *naf**(1d0-ss_x) &
                    & *alf**(1d0+ss_x) &
                    & *(3d0-ss_x)*sif**(3d0-ss_x-1d0)*dsif_dpro &
                    & /prox**(4d0 + 4d0*ss_x) &
                    & /keq_tmp &
                    & + &
                    & caf**ss_x &
                    & *naf**(1d0-ss_x) &
                    & *alf**(1d0+ss_x) &
                    & *sif**(3d0-ss_x) &
                    & *(-1d0*(4d0 + 4d0*ss_x))/prox**(4d0 + 4d0*ss_x+1d0) &
                    & /keq_tmp &
                    & )
            case('so4f')
                domega_dmsp = ( & 
                    & ss_x*caf**(ss_x-1d0)*dcaf_dso4f &
                    & *naf**(1d0-ss_x) &
                    & *alf**(1d0+ss_x) &
                    & *sif**(3d0-ss_x) &
                    & /prox**(4d0 + 4d0*ss_x) &
                    & /keq_tmp &
                    & + &
                    & caf**ss_x &
                    & *(1d0-ss_x)*naf**(1d0-ss_x-1d0)*dnaf_dso4f &
                    & *alf**(1d0+ss_x) &
                    & *sif**(3d0-ss_x) &
                    & /prox**(4d0 + 4d0*ss_x) &
                    & /keq_tmp &
                    & + &
                    & caf**ss_x &
                    & *naf**(1d0-ss_x) &
                    & *(1d0+ss_x)*alf**(1d0+ss_x-1d0)*dalf_dso4f &
                    & *sif**(3d0-ss_x) &
                    & /prox**(4d0 + 4d0*ss_x) &
                    & /keq_tmp &
                    & + &
                    & caf**ss_x &
                    & *naf**(1d0-ss_x) &
                    & *alf**(1d0+ss_x) &
                    & *(3d0-ss_x)*sif**(3d0-ss_x-1d0)*dsif_dso4f &
                    & /prox**(4d0 + 4d0*ss_x) &
                    & /keq_tmp &
                    & )
            case('pco2')
                domega_dmsp = ( & 
                    & ss_x*caf**(ss_x-1d0)*dcaf_dpco2 &
                    & *naf**(1d0-ss_x) &
                    & *alf**(1d0+ss_x) &
                    & *sif**(3d0-ss_x) &
                    & /prox**(4d0 + 4d0*ss_x) &
                    & /keq_tmp &
                    & + &
                    & caf**ss_x &
                    & *(1d0-ss_x)*naf**(1d0-ss_x-1d0)*dnaf_dpco2 &
                    & *alf**(1d0+ss_x) &
                    & *sif**(3d0-ss_x) &
                    & /prox**(4d0 + 4d0*ss_x) &
                    & /keq_tmp &
                    & + &
                    & caf**ss_x &
                    & *naf**(1d0-ss_x) &
                    & *(1d0+ss_x)*alf**(1d0+ss_x-1d0)*dalf_dpco2 &
                    & *sif**(3d0-ss_x) &
                    & /prox**(4d0 + 4d0*ss_x) &
                    & /keq_tmp &
                    & + &
                    & caf**ss_x &
                    & *naf**(1d0-ss_x) &
                    & *alf**(1d0+ss_x) &
                    & *(3d0-ss_x)*sif**(3d0-ss_x-1d0)*dsif_dpco2 &
                    & /prox**(4d0 + 4d0*ss_x) &
                    & /keq_tmp &
                    & )
            case('ca')
                domega_dmsp = ( & 
                    & ss_x*caf**(ss_x-1d0)*dcaf_dca &
                    & *naf**(1d0-ss_x) &
                    & *alf**(1d0+ss_x) &
                    & *sif**(3d0-ss_x) &
                    & /prox**(4d0 + 4d0*ss_x) &
                    & /keq_tmp &
                    & )
            case('na')
                domega_dmsp = ( & 
                    & caf**ss_x &
                    & *(1d0-ss_x)*naf**(1d0-ss_x-1d0)*dnaf_dna &
                    & *alf**(1d0+ss_x) &
                    & *sif**(3d0-ss_x) &
                    & /prox**(4d0 + 4d0*ss_x) &
                    & /keq_tmp &
                    & )
            case('al')
                domega_dmsp = ( & 
                    & caf**ss_x &
                    & *naf**(1d0-ss_x) &
                    & *(1d0+ss_x)*alf**(1d0+ss_x-1d0)*dalf_dal &
                    & *sif**(3d0-ss_x) &
                    & /prox**(4d0 + 4d0*ss_x) &
                    & /keq_tmp &
                    & )
            case('si')
                domega_dmsp = ( & 
                    & caf**ss_x &
                    & *naf**(1d0-ss_x) &
                    & *alf**(1d0+ss_x) &
                    & *(3d0-ss_x)*sif**(3d0-ss_x-1d0)*dsif_dsi &
                    & /prox**(4d0 + 4d0*ss_x) &
                    & /keq_tmp &
                    & )
            case default 
                domega_dmsp = 0d0
        endselect 
        
        
    case('cc')
        omega = ( &
            & caf &
            & *k1*k2*kco2*pco2x/(prox**2d0) &
            & /keqcc &
            & )
            
        select case(trim(adjustl(sp_name)))
            case('pro')
                domega_dmsp = ( & 
                    & 1d0*dcaf_dpro &
                    & *k1*k2*kco2*pco2x/(prox**2d0) &
                    & /keqcc &
                    & + &
                    & caf &
                    & *k1*k2*kco2*pco2x*(-2d0)/(prox**3d0) &
                    & /keqcc &
                    & )
            case('so4f')
                domega_dmsp = ( & 
                    & 1d0*dcaf_dso4f &
                    & *k1*k2*kco2*pco2x/(prox**2d0) &
                    & /keqcc &
                    & )
            case('pco2')
                domega_dmsp = ( & 
                    & 1d0*dcaf_dpco2 &
                    & *k1*k2*kco2*pco2x/(prox**2d0) &
                    & /keqcc &
                    & + &
                    & caf &
                    & *k1*k2*kco2*1d0/(prox**2d0) &
                    & /keqcc &
                    & )
            case('ca')
                domega_dmsp = ( & 
                    & 1d0*dcaf_dca &
                    & *k1*k2*kco2*pco2x/(prox**2d0) &
                    & /keqcc &
                    & )
            case default 
                domega_dmsp = 0d0
        endselect 
        
        
    case('arg')
        keq_tmp = keqsld_all(findloc(chrsld_all,'arg',dim=1))
        omega = ( &
            & caf &
            & *k1*k2*kco2*pco2x/(prox**2d0) &
            & /keq_tmp &
            & )
            
        select case(trim(adjustl(sp_name)))
            case('pro')
                domega_dmsp = ( & 
                    & 1d0*dcaf_dpro &
                    & *k1*k2*kco2*pco2x/(prox**2d0) &
                    & /keq_tmp &
                    & + &
                    & caf &
                    & *k1*k2*kco2*pco2x*(-2d0)/(prox**3d0) &
                    & /keq_tmp &
                    & )
            case('so4f')
                domega_dmsp = ( & 
                    & 1d0*dcaf_dso4f &
                    & *k1*k2*kco2*pco2x/(prox**2d0) &
                    & /keq_tmp &
                    & )
            case('pco2')
                domega_dmsp = ( & 
                    & 1d0*dcaf_dpco2 &
                    & *k1*k2*kco2*pco2x/(prox**2d0) &
                    & /keq_tmp &
                    & + &
                    & caf &
                    & *k1*k2*kco2*1d0/(prox**2d0) &
                    & /keq_tmp &
                    & )
            case('ca')
                domega_dmsp = ( & 
                    & 1d0*dcaf_dca &
                    & *k1*k2*kco2*pco2x/(prox**2d0) &
                    & /keq_tmp &
                    & )
            case default 
                domega_dmsp = 0d0
        endselect 
        
        
    case('dlm')
        keq_tmp = keqsld_all(findloc(chrsld_all,'dlm',dim=1))
        omega = ( &
            & caf*mgf &
            & *(k1*k2*kco2*pco2x/(prox**2d0))**2d0 &
            & /keq_tmp &
            & )
            
        select case(trim(adjustl(sp_name)))
            case('pro')
                domega_dmsp = ( & 
                    & dcaf_dpro*mgf &
                    & *(k1*k2*kco2*pco2x/(prox**2d0))**2d0 &
                    & /keq_tmp &
                    & + &
                    & caf*dmgf_dpro &
                    & *(k1*k2*kco2*pco2x/(prox**2d0))**2d0 &
                    & /keq_tmp &
                    & + &
                    & caf*mgf &
                    & *2d0*(k1*k2*kco2*pco2x/(prox**2d0))*k1*k2*kco2*pco2x*(-2d0)/(prox**3d0) &
                    & /keq_tmp &
                    & )
            case('so4f')
                domega_dmsp = ( & 
                    & dcaf_dso4f*mgf &
                    & *(k1*k2*kco2*pco2x/(prox**2d0))**2d0 &
                    & /keq_tmp &
                    & + &
                    & caf*dmgf_dso4f &
                    & *(k1*k2*kco2*pco2x/(prox**2d0))**2d0 &
                    & /keq_tmp &
                    & )
            case('pco2')
                domega_dmsp = ( & 
                    & dcaf_dpco2*mgf &
                    & *(k1*k2*kco2*pco2x/(prox**2d0))**2d0 &
                    & /keq_tmp &
                    & + &
                    & caf*dmgf_dpco2 &
                    & *(k1*k2*kco2*pco2x/(prox**2d0))**2d0 &
                    & /keq_tmp &
                    & + &
                    & caf*mgf &
                    & *2d0*(k1*k2*kco2*pco2x/(prox**2d0))*k1*k2*kco2*1d0/(prox**2d0) &
                    & /keq_tmp &
                    & )
            case('ca')
                domega_dmsp = ( & 
                    & dcaf_dca*mgf &
                    & *(k1*k2*kco2*pco2x/(prox**2d0))**2d0 &
                    & /keq_tmp &
                    & )
            case('mg')
                domega_dmsp = ( & 
                    & caf*dmgf_dmg &
                    & *(k1*k2*kco2*pco2x/(prox**2d0))**2d0 &
                    & /keq_tmp &
                    & )
            case default 
                domega_dmsp = 0d0
        endselect 
        
        
    case('ka')
    ! Al2Si2O5(OH)4 + 6 H+ = H2O + 2 H4SiO4 + 2 Al+3 
        omega = ( &
            & alf**2d0 &
            & *sif**2d0 &
            & /prox**6d0 &
            & /keqka &
            & )
            
        select case(trim(adjustl(sp_name)))
            case('pro')
                ! ph dependences of al and si are from an case
                domega_dmsp = ( & 
                    & alf*2d0*dalf_dpro &
                    & *sif**2d0 &
                    & /prox**6d0 &
                    & /keqka &
                    & + &
                    & alf**2d0 &
                    & *sif*2d0*dsif_dpro &
                    & /prox**6d0 &
                    & /keqka &
                    & + &
                    & alf**2d0 &
                    & *sif**2d0 &
                    & *(-6d0)/prox**7d0 &
                    & /keqka &
                    ! 
                    & )
            case('so4f')
                ! ph dependences of al and si are from an case
                domega_dmsp = ( & 
                    & alf*2d0*dalf_dso4f &
                    & *sif**2d0 &
                    & /prox**6d0 &
                    & /keqka &
                    & + &
                    & alf**2d0 &
                    & *sif*2d0*dsif_dso4f &
                    & /prox**6d0 &
                    & /keqka &
                    ! 
                    & )
            case('al')
                domega_dmsp = ( & 
                    & alf*2d0*dalf_dal &
                    & *sif**2d0 &
                    & /prox**6d0 &
                    & /keqka &
                    & )
            case('si')
                domega_dmsp = ( & 
                    & alf**2d0 &
                    & *sif*2d0*dsif_dsi &
                    & /prox**6d0 &
                    & /keqka &
                    & )
            case default 
                domega_dmsp = 0d0
        endselect 
        
        
    case('gb')
    ! Al(OH)3 + 3 H+ = Al+3 + 3 H2O 
        omega = ( &
            & alf &
            & /prox**3d0 &
            & /keqgb &
            & )
            
        select case(trim(adjustl(sp_name)))
            case('pro')
                ! ph dependence of al is from an case
                domega_dmsp = ( & 
                    & 1d0*dalf_dpro &
                    & /prox**3d0 &
                    & /keqgb &
                    & + &
                    & alf &
                    & *(-3d0)/prox**4d0 &
                    & /keqgb &
                    ! 
                    & )
            case('so4f')
                ! ph dependence of al is from an case
                domega_dmsp = ( & 
                    & 1d0*dalf_dso4f &
                    & /prox**3d0 &
                    & /keqgb &
                    ! 
                    & )
            case('al')
                domega_dmsp = ( & 
                    & 1d0*dalf_dal &
                    & /prox**3d0 &
                    & /keqgb &
                    & )
            case default 
                domega_dmsp = 0d0
        endselect 
        
    case('amsi')
    ! SiO2 + 2 H2O = H4SiO4
        omega = ( &
            & sif &
            & /keqamsi &
            & )
            
        select case(trim(adjustl(sp_name)))
            case('pro')
                domega_dmsp = ( & 
                    & 1d0*dsif_dpro &
                    & /keqamsi &
                    ! 
                    & )
            case('so4f')
                domega_dmsp = ( & 
                    & 1d0*dsif_dso4f &
                    & /keqamsi &
                    ! 
                    & )
            case('si')
                domega_dmsp = ( & 
                    & 1d0*dsif_dsi &
                    & /keqamsi &
                    & )
            case default 
                domega_dmsp = 0d0
        endselect 
        
    case('qtz')
    !  SiO2 + 2H2O = H4SiO4
        keq_tmp = keqsld_all(findloc(chrsld_all,'qtz',dim=1))
        omega = ( &
            & sif &
            & /keq_tmp &
            & )
            
        select case(trim(adjustl(sp_name)))
            case('pro')
                domega_dmsp = ( & 
                    & 1d0*dsif_dpro &
                    & /keq_tmp &
                    ! 
                    & )
            case('so4f')
                domega_dmsp = ( & 
                    & 1d0*dsif_dso4f &
                    & /keq_tmp &
                    ! 
                    & )
            case('si')
                domega_dmsp = ( & 
                    & 1d0*dsif_dsi &
                    & /keq_tmp &
                    & )
            case default 
                domega_dmsp = 0d0
        endselect 
        
        
    case('gt')
    !  Fe(OH)3 + 3 H+ = Fe+3 + 2 H2O
        omega = (&
            & fe3f &
            & /prox**3d0 &
            & /keqgt &
            & )
            
        ! copied and pasted from gb case with replacing al and gb with fe3 and gt respectively
        select case(trim(adjustl(sp_name)))
            case('pro')
                domega_dmsp = ( & 
                    & dfe3f_dpro &
                    & /prox**3d0 &
                    & /keqgt &
                    & + &
                    & fe3f &
                    & *(-3d0)/prox**4d0 &
                    & /keqgt &
                    ! 
                    & )
            case('so4f')
                domega_dmsp = ( & 
                    & dfe3f_dso4f &
                    & /prox**3d0 &
                    & /keqgt &
                    ! 
                    & )
            case('fe3')
                domega_dmsp = ( & 
                    & dfe3f_dfe3 &
                    & /prox**3d0 &
                    & /keqgt &
                    & )
            case default 
                domega_dmsp = 0d0
        endselect 
        
        
    case('hm')
    !  Fe2O3 + 6H+ = 2Fe+3 + 3H2O
        keq_tmp = keqsld_all(findloc(chrsld_all,'hm',dim=1))
        omega = (&
            & fe3f**2d0 &
            & /prox**6d0 &
            & /keq_tmp &
            & )
            
        ! copied and pasted from gb case with replacing al and gb with fe3 and gt respectively
        select case(trim(adjustl(sp_name)))
            case('pro')
                domega_dmsp = ( & 
                    & 2d0*fe3f*dfe3f_dpro &
                    & /prox**6d0 &
                    & /keq_tmp &
                    & + &
                    & fe3f**2d0 &
                    & *(-6d0)/prox**7d0 &
                    & /keq_tmp &
                    ! 
                    & )
            case('so4f')
                domega_dmsp = ( & 
                    & 2d0*fe3f*dfe3f_dso4f &
                    & /prox**6d0 &
                    & /keq_tmp &
                    ! 
                    & )
            case('fe3')
                domega_dmsp = ( & 
                    & 2d0*fe3f*dfe3f_dfe3 &
                    & /prox**6d0 &
                    & /keq_tmp &
                    & )
            case default 
                domega_dmsp = 0d0
        endselect 
        
        
    case('ct')
    ! Mg3Si2O5(OH)4 + 6 H+ = H2O + 2 H4SiO4 + 3 Mg+2
        omega = ( &
            & mgf**3d0 &
            & *sif**2d0  &
            & /prox**6d0 &
            & /keqct &
            & )
            
            
        select case(trim(adjustl(sp_name)))
            case('pro')
                ! ph dependence of mg and si are from above
                domega_dmsp = ( & 
                    & 3d0*mgf**2d0*dmgf_dpro &
                    & *sif**2d0  &
                    & /prox**6d0 &
                    & /keqct &
                    & + &
                    & mgf**3d0 &
                    & *sif*2d0*dsif_dpro  &
                    & /prox**6d0 &
                    & /keqct &
                    & + &
                    & mgf**3d0 &
                    & *sif**2d0  &
                    & *(-6d0)/prox**7d0 &
                    & /keqct &
                    & )
            case('so4f')
                ! ph dependence of mg and si are from above
                domega_dmsp = ( & 
                    & 3d0*mgf**2d0*dmgf_dso4f &
                    & *sif**2d0  &
                    & /prox**6d0 &
                    & /keqct &
                    & + &
                    & mgf**3d0 &
                    & *sif*2d0*dsif_dso4f  &
                    & /prox**6d0 &
                    & /keqct &
                    & )
            case('pco2')
                ! pco2 dependence of mg is from fo case
                domega_dmsp = ( & 
                    & 3d0*mgf**2d0*dmgf_dpco2 &
                    & *sif**2d0  &
                    & /prox**6d0 &
                    & /keqct &
                    & )
            case('mg')
                domega_dmsp = ( & 
                    & 3d0*mgf**2d0*dmgf_dmg &
                    & *sif**2d0  &
                    & /prox**6d0 &
                    & /keqct &
                    & )
            case('si')
                domega_dmsp = ( & 
                    & mgf**3d0 &
                    & *sif*2d0*dsif_dsi  &
                    & /prox**6d0 &
                    & /keqct &
                    & )
            case default 
                domega_dmsp = 0d0
        endselect 
        
        
    case('cabd')
    ! Beidellit-Ca  + 7.32 H+  = 4.66 H2O  + 2.33 Al+++  + 3.67 SiO2(aq)  + .165 Ca++
        omega = ( &
            & caf**(1d0/6d0) &
            & *alf**(7d0/3d0) &
            & *sif**(11d0/3d0) &
            & /prox**(22d0/3d0) &
            & /keqcabd &
            & )
            
        ! dependences from an case
        select case(trim(adjustl(sp_name)))
            case('pro')
                domega_dmsp = ( &
                    & (1d0/6d0)*caf**(1d0/6d0-1d0)*dcaf_dpro &
                    & *alf**(7d0/3d0) &
                    & *sif**(11d0/3d0) &
                    & /prox**(22d0/3d0) &
                    & /keqcabd &
                    & + &
                    & caf**(1d0/6d0) &
                    & *(7d0/3d0)*alf**(7d0/3d0-1d0)*dalf_dpro &
                    & *sif**(11d0/3d0) &
                    & /prox**(22d0/3d0) &
                    & /keqcabd &
                    & + &
                    & caf**(1d0/6d0) &
                    & *alf**(7d0/3d0) &
                    & *(11d0/3d0)*sif**(11d0/3d0-1d0)*dsif_dpro &
                    & /prox**(22d0/3d0) &
                    & /keqcabd &
                    & + &
                    & caf**(1d0/6d0) &
                    & *alf**(7d0/3d0) &
                    & *sif**(11d0/3d0) &
                    & *(-22d0/3d0)/prox**(22d0/3d0+1d0) &
                    & /keqcabd &
                    & )
            case('so4f')
                domega_dmsp = ( &
                    & (1d0/6d0)*caf**(1d0/6d0-1d0)*dcaf_dso4f &
                    & *alf**(7d0/3d0) &
                    & *sif**(11d0/3d0) &
                    & /prox**(22d0/3d0) &
                    & /keqcabd &
                    & + &
                    & caf**(1d0/6d0) &
                    & *(7d0/3d0)*alf**(7d0/3d0-1d0)*dalf_dso4f &
                    & *sif**(11d0/3d0) &
                    & /prox**(22d0/3d0) &
                    & /keqcabd &
                    & + &
                    & caf**(1d0/6d0) &
                    & *alf**(7d0/3d0) &
                    & *(11d0/3d0)*sif**(11d0/3d0-1d0)*dsif_dso4f &
                    & /prox**(22d0/3d0) &
                    & /keqcabd &
                    & )
            case('pco2')
                domega_dmsp = ( & 
                    & (1d0/6d0)*caf**(1d0/6d0-1d0)*dcaf_dpco2 &
                    & *alf**(7d0/3d0) &
                    & *sif**(11d0/3d0) &
                    & /prox**(22d0/3d0) &
                    & /keqcabd &
                    & )
            case('ca')
                domega_dmsp = ( & 
                    & (1d0/6d0)*caf**(1d0/6d0-1d0)*dcaf_dca &
                    & *alf**(7d0/3d0) &
                    & *sif**(11d0/3d0) &
                    & /prox**(22d0/3d0) &
                    & /keqcabd &
                    & )
            case('al')
                domega_dmsp = ( & 
                    & caf**(1d0/6d0) &
                    & *(7d0/3d0)*alf**(7d0/3d0-1d0)*dalf_dal &
                    & *sif**(11d0/3d0) &
                    & /prox**(22d0/3d0) &
                    & /keqcabd &
                    & )
            case('si')
                domega_dmsp = ( & 
                    & caf**(1d0/6d0) &
                    & *alf**(7d0/3d0) &
                    & *(11d0/3d0)*sif**(11d0/3d0-1d0)*dsif_dsi &
                    & /prox**(22d0/3d0) &
                    & /keqcabd &
                    & )
            case default 
                domega_dmsp = 0d0
        endselect 
        
        
    case('ill')
    ! Illite  + 8 H+  = 5 H2O  + .6 K+  + .25 Mg++  + 2.3 Al+++  + 3.5 SiO2(aq)
        keq_tmp = keqsld_all(findloc(chrsld_all,'ill',dim=1))
        omega = (  &
            & kf**(0.6d0) &
            & *mgf**(0.25d0) &
            & *alf**(2.3d0)  &
            & *sif**(3.5d0)   &
            & /prox**(8d0)    &
            & /keq_tmp      &
            & )
            
        ! dependences from an case
        select case(trim(adjustl(sp_name)))
            case('pro')
                domega_dmsp = ( &
                    & 0.6d0*kf**(0.6d0-1d0)*dkf_dpro &
                    & *mgf**(0.25d0) &
                    & *alf**(2.3d0)  &
                    & *sif**(3.5d0)   &
                    & /prox**(8d0)    &
                    & /keq_tmp      &
                    & + &
                    & kf**(0.6d0) &
                    & *0.25d0*mgf**(0.25d0-1d0)*dmgf_dpro &
                    & *alf**(2.3d0)  &
                    & *sif**(3.5d0)   &
                    & /prox**(8d0)    &
                    & /keq_tmp      &
                    & + &
                    & kf**(0.6d0) &
                    & *mgf**(0.25d0) &
                    & *2.3d0*alf**(2.3d0-1d0)*dalf_dpro  &
                    & *sif**(3.5d0)   &
                    & /prox**(8d0)    &
                    & /keq_tmp      &
                    & + &
                    & kf**(0.6d0) &
                    & *mgf**(0.25d0) &
                    & *alf**(2.3d0)  &
                    & *3.5d0*sif**(3.5d0-1d0)*dsif_dpro   &
                    & /prox**(8d0)    &
                    & /keq_tmp      &
                    & + &
                    & kf**(0.6d0) &
                    & *mgf**(0.25d0) &
                    & *alf**(2.3d0)  &
                    & *sif**(3.5d0)   &
                    & *(-8d0)/prox**(9d0)    &
                    & /keq_tmp      &
                    & )
            case('so4f')
                domega_dmsp = ( &
                    & 0.6d0*kf**(0.6d0-1d0)*dkf_dso4f &
                    & *mgf**(0.25d0) &
                    & *alf**(2.3d0)  &
                    & *sif**(3.5d0)   &
                    & /prox**(8d0)    &
                    & /keq_tmp      &
                    & + &
                    & kf**(0.6d0) &
                    & *0.25d0*mgf**(0.25d0-1d0)*dmgf_dso4f &
                    & *alf**(2.3d0)  &
                    & *sif**(3.5d0)   &
                    & /prox**(8d0)    &
                    & /keq_tmp      &
                    & + &
                    & kf**(0.6d0) &
                    & *mgf**(0.25d0) &
                    & *2.3d0*alf**(2.3d0-1d0)*dalf_dso4f  &
                    & *sif**(3.5d0)   &
                    & /prox**(8d0)    &
                    & /keq_tmp      &
                    & + &
                    & kf**(0.6d0) &
                    & *mgf**(0.25d0) &
                    & *alf**(2.3d0)  &
                    & *3.5d0*sif**(3.5d0-1d0)*dsif_dso4f   &
                    & /prox**(8d0)    &
                    & /keq_tmp      &
                    & )
            case('pco2')
                domega_dmsp = ( & 
                    & 0.6d0*kf**(0.6d0-1d0)*dkf_dpco2 &
                    & *mgf**(0.25d0) &
                    & *alf**(2.3d0)  &
                    & *sif**(3.5d0)   &
                    & /prox**(8d0)    &
                    & /keq_tmp      &
                    & + &
                    & kf**(0.6d0) &
                    & *0.25d0*mgf**(0.25d0-1d0)*dmgf_dpco2 &
                    & *alf**(2.3d0)  &
                    & *sif**(3.5d0)   &
                    & /prox**(8d0)    &
                    & /keq_tmp      &
                    & + &
                    & kf**(0.6d0) &
                    & *mgf**(0.25d0) &
                    & *2.3d0*alf**(2.3d0-1d0)*dalf_dpco2  &
                    & *sif**(3.5d0)   &
                    & /prox**(8d0)    &
                    & /keq_tmp      &
                    & + &
                    & kf**(0.6d0) &
                    & *mgf**(0.25d0) &
                    & *alf**(2.3d0)  &
                    & *3.5d0*sif**(3.5d0-1d0)*dsif_dpco2   &
                    & /prox**(8d0)    &
                    & /keq_tmp      &
                    & )
            case('k')
                domega_dmsp = ( & 
                    & 0.6d0*kf**(0.6d0-1d0)*dkf_dk &
                    & *mgf**(0.25d0) &
                    & *alf**(2.3d0)  &
                    & *sif**(3.5d0)   &
                    & /prox**(8d0)    &
                    & /keq_tmp      &
                    & )
            case('mg')
                domega_dmsp = ( & 
                    & kf**(0.6d0) &
                    & *0.25d0*mgf**(0.25d0-1d0)*dmgf_dmg &
                    & *alf**(2.3d0)  &
                    & *sif**(3.5d0)   &
                    & /prox**(8d0)    &
                    & /keq_tmp      &
                    & )
            case('al')
                domega_dmsp = ( & 
                    & kf**(0.6d0) &
                    & *mgf**(0.25d0) &
                    & *2.3d0*alf**(2.3d0-1d0)*dalf_dal  &
                    & *sif**(3.5d0)   &
                    & /prox**(8d0)    &
                    & /keq_tmp      &
                    & )
            case('si')
                domega_dmsp = ( & 
                    & kf**(0.6d0) &
                    & *mgf**(0.25d0) &
                    & *alf**(2.3d0)  &
                    & *3.5d0*sif**(3.5d0-1d0)*dsif_dsi   &
                    & /prox**(8d0)    &
                    & /keq_tmp      &
                    & )
            case default 
                domega_dmsp = 0d0
        endselect 
        
        
    case('anl')
    ! NaAlSi2O6*H2O  + 5 H2O  = Na+  + Al(OH)4-  + 2 Si(OH)4(aq)
        keq_tmp = keqsld_all(findloc(chrsld_all,'anl',dim=1))
        omega = (  &
            & naf &
            & *alf*k4al/prox**4d0  &
            & *sif**2d0   &
            & /keq_tmp      &
            & )
            
        ! dependences from an case
        select case(trim(adjustl(sp_name)))
            case('pro')
                domega_dmsp = ( &
                    & dnaf_dpro &
                    & *alf*k4al/prox**4d0  &
                    & *sif**2d0   &
                    & /keq_tmp      &
                    & + &
                    & naf &
                    & *dalf_dpro*k4al/prox**4d0  &
                    & *sif**2d0   &
                    & /keq_tmp      &
                    & + &
                    & naf &
                    & *alf*k4al*(-4d0)/prox**5d0  &
                    & *sif**2d0   &
                    & /keq_tmp      &
                    & + &
                    & naf &
                    & *alf*k4al/prox**4d0  &
                    & *2d0*sif*dsif_dpro   &
                    & /keq_tmp      &
                    & )
            case('so4f')
                domega_dmsp = ( &
                    & dnaf_dso4f &
                    & *alf*k4al/prox**4d0  &
                    & *sif**2d0   &
                    & /keq_tmp      &
                    & + &
                    & naf &
                    & *dalf_dso4f*k4al/prox**4d0  &
                    & *sif**2d0   &
                    & /keq_tmp      &
                    & + &
                    & naf &
                    & *alf*k4al/prox**4d0  &
                    & *2d0*sif*dsif_dso4f   &
                    & /keq_tmp      &
                    & )
            case('pco2')
                domega_dmsp = ( & 
                    & dnaf_dpco2 &
                    & *alf*k4al/prox**4d0  &
                    & *sif**2d0   &
                    & /keq_tmp      &
                    & + &
                    & naf &
                    & *dalf_dpco2*k4al/prox**4d0  &
                    & *sif**2d0   &
                    & /keq_tmp      &
                    & + &
                    & naf &
                    & *alf*k4al/prox**4d0  &
                    & *2d0*sif*dsif_dpco2   &
                    & /keq_tmp      &
                    & )
            case('na')
                domega_dmsp = ( & 
                    & dnaf_dna &
                    & *alf*k4al/prox**4d0  &
                    & *sif**2d0   &
                    & /keq_tmp      &
                    & )
            case('al')
                domega_dmsp = ( & 
                    & naf &
                    & *dalf_dal*k4al/prox**4d0  &
                    & *sif**2d0   &
                    & /keq_tmp      &
                    & )
            case('si')
                domega_dmsp = ( & 
                    & naf &
                    & *alf*k4al/prox**4d0  &
                    & *2d0*sif*dsif_dsi   &
                    & /keq_tmp      &
                    & )
            case default 
                domega_dmsp = 0d0
        endselect 
        
        
    case('nph')
    ! Nepheline  + 4 H+  = 2 H2O  + SiO2(aq)  + Al+++  + Na+
        keq_tmp = keqsld_all(findloc(chrsld_all,'nph',dim=1))
        omega = (  &
            & naf &
            & *alf  &
            & *sif   &
            & /prox**4d0  &
            & /keq_tmp      &
            & )
            
        ! dependences from an case
        select case(trim(adjustl(sp_name)))
            case('pro')
                domega_dmsp = ( &
                    & dnaf_dpro &
                    & *alf  &
                    & *sif   &
                    & /prox**4d0 &
                    & /keq_tmp      &
                    & + &
                    & naf &
                    & *dalf_dpro  &
                    & *sif   &
                    & /prox**4d0 &
                    & /keq_tmp      &
                    & + &
                    & naf &
                    & *alf  &
                    & *dsif_dpro   &
                    & /prox**4d0 &
                    & /keq_tmp      &
                    & + &
                    & naf &
                    & *alf  &
                    & *sif   &
                    & *(-4d0)/prox**5d0 &
                    & /keq_tmp      &
                    & )
            case('so4f')
                domega_dmsp = ( &
                    & dnaf_dso4f &
                    & *alf  &
                    & *sif   &
                    & /prox**4d0 &
                    & /keq_tmp      &
                    & + &
                    & naf &
                    & *dalf_dso4f  &
                    & *sif   &
                    & /prox**4d0 &
                    & /keq_tmp      &
                    & + &
                    & naf &
                    & *alf  &
                    & *dsif_dso4f   &
                    & /prox**4d0 &
                    & /keq_tmp      &
                    & )
            case('pco2')
                domega_dmsp = ( & 
                    & dnaf_dpco2 &
                    & *alf  &
                    & *sif   &
                    & /prox**4d0 &
                    & /keq_tmp      &
                    & + &
                    & naf &
                    & *dalf_dpco2  &
                    & *sif   &
                    & /prox**4d0 &
                    & /keq_tmp      &
                    & + &
                    & naf &
                    & *alf  &
                    & *dsif_dpco2   &
                    & /prox**4d0 &
                    & /keq_tmp      &
                    & )
            case('na')
                domega_dmsp = ( & 
                    & dnaf_dna &
                    & *alf  &
                    & *sif   &
                    & /prox**4d0 &
                    & /keq_tmp      &
                    & )
            case('al')
                domega_dmsp = ( & 
                    & naf &
                    & *dalf_dal  &
                    & *sif   &
                    & /prox**4d0 &
                    & /keq_tmp      &
                    & )
            case('si')
                domega_dmsp = ( & 
                    & naf &
                    & *alf  &
                    & *dsif_dsi   &
                    & /prox**4d0 &
                    & /keq_tmp      &
                    & )
            case default 
                domega_dmsp = 0d0
        endselect 
        
        
    case('dp')
    ! Diopside  + 4 H+  = Ca++  + 2 H2O  + Mg++  + 2 SiO2(aq)
        omega = ( &
            & caf &
            & *mgf &
            & *sif**2d0 &
            & /prox**4d0 &
            & /keqdp &
            & )
            
        ! dependences from an case
        select case(trim(adjustl(sp_name)))
            case('pro')
                domega_dmsp = ( &   
                    & dcaf_dpro &
                    & *mgf &
                    & *sif**2d0 &
                    & /prox**4d0 &
                    & /keqdp &
                    & + &
                    & caf &
                    & *dmgf_dpro &
                    & *sif**2d0 &
                    & /prox**4d0 &
                    & /keqdp &
                    & + &
                    & caf &
                    & *mgf &
                    & *sif*2d0*dsif_dpro &
                    & /prox**4d0 &
                    & /keqdp &
                    & + &
                    & caf &
                    & *mgf &
                    & *sif**2d0 &
                    & *(-4d0)/prox**5d0 &
                    & /keqdp &
                    & )
            case('so4f')
                domega_dmsp = ( &   
                    & dcaf_dso4f &
                    & *mgf &
                    & *sif**2d0 &
                    & /prox**4d0 &
                    & /keqdp &
                    & + &
                    & caf &
                    & *dmgf_dso4f &
                    & *sif**2d0 &
                    & /prox**4d0 &
                    & /keqdp &
                    & + &
                    & caf &
                    & *mgf &
                    & *sif*2d0*dsif_dso4f &
                    & /prox**4d0 &
                    & /keqdp &
                    & )
            case('pco2')
                domega_dmsp = ( & 
                    & dcaf_dpco2 &
                    & *mgf &
                    & *sif**2d0 &
                    & /prox**4d0 &
                    & /keqdp &
                    & + &
                    & caf &
                    & *dmgf_dpco2 &
                    & *sif**2d0 &
                    & /prox**4d0 &
                    & /keqdp &
                    & )
            case('mg')
                domega_dmsp = ( & 
                    & caf &
                    & *dmgf_dmg &
                    & *sif**2d0 &
                    & /prox**4d0 &
                    & /keqdp &
                    & )
            case('ca')
                domega_dmsp = ( & 
                    & dcaf_dca &
                    & *mgf &
                    & *sif**2d0 &
                    & /prox**4d0 &
                    & /keqdp &
                    & )
            case('si')
                domega_dmsp = ( & 
                    & caf &
                    & *mgf &
                    & *sif*2d0*dsif_dsi &
                    & /prox**4d0 &
                    & /keqdp &
                    & )
            case default 
                domega_dmsp = 0d0
        endselect 
        
        
    case('hb')
    ! Hedenbergite  + 4 H+  = 2 H2O  + 2 SiO2(aq)  + Fe++  + Ca++
        omega = ( &
            & caf &
            & *fe2f &
            & *sif**2d0 &
            & /prox**4d0 &
            & /keqhb &
            & )
            
        ! copied and pasted from dp case with replacing mg and dp by fe2 and hb
        select case(trim(adjustl(sp_name)))
            case('pro')
                domega_dmsp = ( &   
                    & dcaf_dpro &
                    & *fe2f &
                    & *sif**2d0 &
                    & /prox**4d0 &
                    & /keqhb &
                    & + &
                    & caf &
                    & *dfe2f_dpro &
                    & *sif**2d0 &
                    & /prox**4d0 &
                    & /keqhb &
                    & + &
                    & caf &
                    & *fe2f &
                    & *sif*2d0*dsif_dpro &
                    & /prox**4d0 &
                    & /keqhb &
                    & + &
                    & caf &
                    & *fe2f &
                    & *sif**2d0 &
                    & *(-4d0)/prox**5d0 &
                    & /keqhb &
                    & )
            case('so4f')
                domega_dmsp = ( &   
                    & dcaf_dso4f &
                    & *fe2f &
                    & *sif**2d0 &
                    & /prox**4d0 &
                    & /keqhb &
                    & + &
                    & caf &
                    & *dfe2f_dso4f &
                    & *sif**2d0 &
                    & /prox**4d0 &
                    & /keqhb &
                    & + &
                    & caf &
                    & *fe2f &
                    & *sif*2d0*dsif_dso4f &
                    & /prox**4d0 &
                    & /keqhb &
                    & )
            case('pco2')
                domega_dmsp = ( & 
                    & dcaf_dpco2 &
                    & *fe2f &
                    & *sif**2d0 &
                    & /prox**4d0 &
                    & /keqhb &
                    & + &
                    & caf &
                    & *dfe2f_dpco2 &
                    & *sif**2d0 &
                    & /prox**4d0 &
                    & /keqhb &
                    & )
            case('fe2')
                domega_dmsp = ( & 
                    & caf &
                    & *dfe2f_dfe2 &
                    & *sif**2d0 &
                    & /prox**4d0 &
                    & /keqhb &
                    & )
            case('ca')
                domega_dmsp = ( & 
                    & dcaf_dca &
                    & *fe2f &
                    & *sif**2d0 &
                    & /prox**4d0 &
                    & /keqhb &
                    & )
            case('si')
                domega_dmsp = ( & 
                    & caf &
                    & *fe2f &
                    & *sif*2d0*dsif_dsi &
                    & /prox**4d0 &
                    & /keqhb &
                    & )
            case default 
                domega_dmsp = 0d0
        endselect 
        
        
    case('cpx')
        ! FexMg(1-x)CaSi2O6  + 4 H+  = 2 H2O  + 2 SiO2(aq)  + xFe++  +  (1-x)Mg++  + Ca++
        keq_tmp = keqsld_all(findloc(chrsld_all,mineral,dim=1))
        ss_x = staq_all(findloc(chrsld_all,mineral,dim=1), findloc(chraq_all,'ca',dim=1) )
        omega = ( &
            & fe2f**ss_x &
            & *mgf**(1d0-ss_x) &
            & *caf &
            & *sif**2d0 &
            & /prox**4d0 &
            & /keq_tmp &
            & )
            
        select case(trim(adjustl(sp_name)))
            case('pro')
                domega_dmsp = ( &   
                    & ss_x*fe2f**(ss_x-1d0)*dfe2f_dpro &
                    & *mgf**(1d0-ss_x) &
                    & *caf &
                    & *sif**2d0 &
                    & /prox**4d0 &
                    & /keq_tmp &
                    & + &
                    & fe2f**ss_x &
                    & *(1d0-ss_x)*mgf**(1d0-ss_x-1d0)*dmgf_dpro &
                    & *caf &
                    & *sif**2d0 &
                    & /prox**4d0 &
                    & /keq_tmp &
                    & + &
                    & fe2f**ss_x &
                    & *mgf**(1d0-ss_x) &
                    & *dcaf_dpro &
                    & *sif**2d0 &
                    & /prox**4d0 &
                    & /keq_tmp &
                    & + &
                    & fe2f**ss_x &
                    & *mgf**(1d0-ss_x) &
                    & *caf &
                    & *2d0*sif*dsif_dpro &
                    & /prox**4d0 &
                    & /keq_tmp &
                    & + &
                    & fe2f**ss_x &
                    & *mgf**(1d0-ss_x) &
                    & *caf &
                    & *sif**2d0 &
                    & *(-4d0)/prox**5d0 &
                    & /keq_tmp &
                    & )
            case('so4f')
                domega_dmsp = ( &   
                    & ss_x*fe2f**(ss_x-1d0)*dfe2f_dso4f &
                    & *mgf**(1d0-ss_x) &
                    & *caf &
                    & *sif**2d0 &
                    & /prox**4d0 &
                    & /keq_tmp &
                    & + &
                    & fe2f**ss_x &
                    & *(1d0-ss_x)*mgf**(1d0-ss_x-1d0)*dmgf_dso4f &
                    & *caf &
                    & *sif**2d0 &
                    & /prox**4d0 &
                    & /keq_tmp &
                    & + &
                    & fe2f**ss_x &
                    & *mgf**(1d0-ss_x) &
                    & *dcaf_dso4f &
                    & *sif**2d0 &
                    & /prox**4d0 &
                    & /keq_tmp &
                    & + &
                    & fe2f**ss_x &
                    & *mgf**(1d0-ss_x) &
                    & *caf &
                    & *2d0*sif*dsif_dso4f &
                    & /prox**4d0 &
                    & /keq_tmp &
                    & )
            case('pco2')
                domega_dmsp = ( & 
                    & ss_x*fe2f**(ss_x-1d0)*dfe2f_dpco2 &
                    & *mgf**(1d0-ss_x) &
                    & *caf &
                    & *sif**2d0 &
                    & /prox**4d0 &
                    & /keq_tmp &
                    & + &
                    & fe2f**ss_x &
                    & *(1d0-ss_x)*mgf**(1d0-ss_x-1d0)*dmgf_dpco2 &
                    & *caf &
                    & *sif**2d0 &
                    & /prox**4d0 &
                    & /keq_tmp &
                    & + &
                    & fe2f**ss_x &
                    & *mgf**(1d0-ss_x) &
                    & *dcaf_dpco2 &
                    & *sif**2d0 &
                    & /prox**4d0 &
                    & /keq_tmp &
                    & + &
                    & fe2f**ss_x &
                    & *mgf**(1d0-ss_x) &
                    & *caf &
                    & *2d0*sif*dsif_dpco2 &
                    & /prox**4d0 &
                    & /keq_tmp &
                    & )
            case('fe2')
                domega_dmsp = ( & 
                    & ss_x*fe2f**(ss_x-1d0)*dfe2f_dfe2 &
                    & *mgf**(1d0-ss_x) &
                    & *caf &
                    & *sif**2d0 &
                    & /prox**4d0 &
                    & /keq_tmp &
                    & )
            case('mg')
                domega_dmsp = ( & 
                    & fe2f**ss_x &
                    & *(1d0-ss_x)*mgf**(1d0-ss_x-1d0)*dmgf_dmg &
                    & *caf &
                    & *sif**2d0 &
                    & /prox**4d0 &
                    & /keq_tmp &
                    & )
            case('ca')
                domega_dmsp = ( & 
                    & fe2f**ss_x &
                    & *mgf**(1d0-ss_x) &
                    & *dcaf_dca &
                    & *sif**2d0 &
                    & /prox**4d0 &
                    & /keq_tmp &
                    & )
            case('si')
                domega_dmsp = ( & 
                    & fe2f**ss_x &
                    & *mgf**(1d0-ss_x) &
                    & *caf &
                    & *2d0*sif*dsif_dsi &
                    & /prox**4d0 &
                    & /keq_tmp &
                    & )
            case default 
                domega_dmsp = 0d0
        endselect 
        
        
    case('opx','en','fer')
        ! FexMg(1-x)SiO3  + 2 H+  = H2O  +  SiO2(aq)  + xFe++  +  (1-x)Mg++  
        keq_tmp = keqsld_all(findloc(chrsld_all,mineral,dim=1))
        ss_x = staq_all(findloc(chrsld_all,mineral,dim=1), findloc(chraq_all,'ca',dim=1) )
        omega = ( &
            & fe2f**ss_x &
            & *mgf**(1d0-ss_x) &
            & *sif &
            & /prox**2d0 &
            & /keq_tmp &
            & )
            
        select case(trim(adjustl(sp_name)))
            case('pro')
                domega_dmsp = ( &   
                    & ss_x*fe2f**(ss_x-1d0)*dfe2f_dpro &
                    & *mgf**(1d0-ss_x) &
                    & *sif &
                    & /prox**2d0 &
                    & /keq_tmp &
                    & + &
                    & fe2f**ss_x &
                    & *(1d0-ss_x)*mgf**(1d0-ss_x-1d0)*dmgf_dpro &
                    & *sif &
                    & /prox**2d0 &
                    & /keq_tmp &
                    & + &
                    & fe2f**ss_x &
                    & *mgf**(1d0-ss_x) &
                    & *dsif_dpro &
                    & /prox**2d0 &
                    & /keq_tmp &
                    & + &
                    & fe2f**ss_x &
                    & *mgf**(1d0-ss_x) &
                    & *sif &
                    & *(-2d0)/prox**3d0 &
                    & /keq_tmp &
                    & )
            case('so4f')
                domega_dmsp = ( &   
                    & ss_x*fe2f**(ss_x-1d0)*dfe2f_dso4f &
                    & *mgf**(1d0-ss_x) &
                    & *sif &
                    & /prox**2d0 &
                    & /keq_tmp &
                    & + &
                    & fe2f**ss_x &
                    & *(1d0-ss_x)*mgf**(1d0-ss_x-1d0)*dmgf_dso4f &
                    & *sif &
                    & /prox**2d0 &
                    & /keq_tmp &
                    & + &
                    & fe2f**ss_x &
                    & *mgf**(1d0-ss_x) &
                    & *dsif_dso4f &
                    & /prox**2d0 &
                    & /keq_tmp &
                    & )
            case('pco2')
                domega_dmsp = ( & 
                    & ss_x*fe2f**(ss_x-1d0)*dfe2f_dpco2 &
                    & *mgf**(1d0-ss_x) &
                    & *sif &
                    & /prox**2d0 &
                    & /keq_tmp &
                    & + &
                    & fe2f**ss_x &
                    & *(1d0-ss_x)*mgf**(1d0-ss_x-1d0)*dmgf_dpco2 &
                    & *sif &
                    & /prox**2d0 &
                    & /keq_tmp &
                    & + &
                    & fe2f**ss_x &
                    & *mgf**(1d0-ss_x) &
                    & *dsif_dpco2 &
                    & /prox**2d0 &
                    & /keq_tmp &
                    & )
            case('fe2')
                domega_dmsp = ( & 
                    & ss_x*fe2f**(ss_x-1d0)*dfe2f_dfe2 &
                    & *mgf**(1d0-ss_x) &
                    & *sif &
                    & /prox**2d0 &
                    & /keq_tmp &
                    & )
            case('mg')
                domega_dmsp = ( & 
                    & fe2f**ss_x &
                    & *(1d0-ss_x)*mgf**(1d0-ss_x-1d0)*dmgf_dmg &
                    & *sif &
                    & /prox**2d0 &
                    & /keq_tmp &
                    & )
            case('si')
                domega_dmsp = ( & 
                    & fe2f**ss_x &
                    & *mgf**(1d0-ss_x) &
                    & *dsif_dsi &
                    & /prox**2d0 &
                    & /keq_tmp &
                    & )
            case default 
                domega_dmsp = 0d0
        endselect 
        
        
    case('tm')
    ! Tremolite  + 14 H+  = 8 H2O  + 8 SiO2(aq)  + 2 Ca++  + 5 Mg++
        keq_tmp = keqsld_all(findloc(chrsld_all,'tm',dim=1))
        omega = ( &
            & caf**2d0 &
            & *mgf**5d0 &
            & *sif**8d0 &
            & /prox**14d0 &
            & /keq_tmp &
            & )
            
        select case(trim(adjustl(sp_name)))
            case('pro')
                domega_dmsp = ( &   
                    & 2d0*caf*dcaf_dpro &
                    & *mgf**5d0 &
                    & *sif**8d0 &
                    & /prox**14d0 &
                    & /keq_tmp &
                    & + &
                    & caf**2d0 &
                    & *5d0*mgf**4d0*dmgf_dpro &
                    & *sif**8d0 &
                    & /prox**14d0 &
                    & /keq_tmp &
                    & + &
                    & caf**2d0 &
                    & *mgf**5d0 &
                    & *8d0*sif**7d0*dsif_dpro &
                    & /prox**14d0 &
                    & /keq_tmp &
                    & + &
                    & caf**2d0 &
                    & *mgf**5d0 &
                    & *sif**8d0 &
                    & *(-14d0)/prox**15d0 &
                    & /keq_tmp &
                    & )
            case('so4f')
                domega_dmsp = ( &   
                    & 2d0*caf*dcaf_dso4f &
                    & *mgf**5d0 &
                    & *sif**8d0 &
                    & /prox**14d0 &
                    & /keq_tmp &
                    & + &
                    & caf**2d0 &
                    & *5d0*mgf**4d0*dmgf_dso4f &
                    & *sif**8d0 &
                    & /prox**14d0 &
                    & /keq_tmp &
                    & + &
                    & caf**2d0 &
                    & *mgf**5d0 &
                    & *8d0*sif**7d0*dsif_dso4f &
                    & /prox**14d0 &
                    & /keq_tmp &
                    & )
            case('pco2')
                domega_dmsp = ( & 
                    & 2d0*caf*dcaf_dpco2 &
                    & *mgf**5d0 &
                    & *sif**8d0 &
                    & /prox**14d0 &
                    & /keq_tmp &
                    & + &
                    & caf**2d0 &
                    & *5d0*mgf**4d0*dmgf_dpco2 &
                    & *sif**8d0 &
                    & /prox**14d0 &
                    & /keq_tmp &
                    & )
            case('mg')
                domega_dmsp = ( & 
                    & caf**2d0 &
                    & *5d0*mgf**4d0*dmgf_dmg &
                    & *sif**8d0 &
                    & /prox**14d0 &
                    & /keq_tmp &
                    & )
            case('ca')
                domega_dmsp = ( & 
                    & 2d0*caf*dcaf_dca &
                    & *mgf**5d0 &
                    & *sif**8d0 &
                    & /prox**14d0 &
                    & /keq_tmp &
                    & )
            case('si')
                domega_dmsp = ( & 
                    & caf**2d0 &
                    & *mgf**5d0 &
                    & *8d0*sif**7d0*dsif_dsi &
                    & /prox**14d0 &
                    & /keq_tmp &
                    & )
            case default 
                domega_dmsp = 0d0
        endselect 
        
        
    case('gps')
    ! CaSO4*2H2O = Ca+2 + SO4-2 + 2H2O
        keq_tmp = keqsld_all(findloc(chrsld_all,'gps',dim=1))
        omega = ( &
            & caf &
            & *so4f &
            & /keq_tmp &
            & )
            
        ! copied and pasted from dp case with replacing mg and dp by fe2 and hb
        select case(trim(adjustl(sp_name)))
            case('pro')
                domega_dmsp = ( &   
                    & dcaf_dpro &
                    & *so4f &
                    & /keq_tmp &
                    & + &
                    & caf &
                    & *dso4f_dpro &
                    & /keq_tmp &
                    & )
            case('so4f')
                domega_dmsp = ( &   
                    & dcaf_dso4f &
                    & *so4f &
                    & /keq_tmp &
                    & + &
                    & caf &
                    & *1d0 &
                    & /keq_tmp &
                    & )
            case('pco2')
                domega_dmsp = ( & 
                    & dcaf_dpco2 &
                    & *so4f &
                    & /keq_tmp &
                    & + &
                    & caf &
                    & *dso4f_dpco2 &
                    & /keq_tmp &
                    & )
            case('ca')
                domega_dmsp = ( & 
                    & dcaf_dca &
                    & *so4f &
                    & /keq_tmp &
                    & )
            case('so4')
                domega_dmsp = ( & 
                    & caf &
                    & *dso4f_dso4 &
                    & /keq_tmp &
                    & )
            case default 
                domega_dmsp = 0d0
        endselect 
        
        
    case('py')
    ! omega is defined so that kpy*poro*hr*mvpy*1d-6*mpyx*(1d0-omega_py) = kpy*poro*hr*mvpy*1d-6*mpyx*po2x**0.5d0
    ! i.e., 1.0 - omega_py = po2x**0.5 
        ! omega = 1d0 - po2x**0.5d0
        omega = 1d0 - po2x**0.5d0*merge(0d0,1d0,po2x<po2th*thon)
        ! omega = merge(1d0,1d0 - po2x**0.5d0,po2x<po2th.or. isnan(po2x**0.5d0) .or. isnan(po2x**(-0.5d0)))
        ! omega = 0d0
        
        select case(trim(adjustl(sp_name)))
            case('po2')
                domega_dmsp = ( &
                    & - 0.5d0/po2x**(0.5d0)*merge(0d0,1d0,po2x<po2th*thon) &
                    & )
                ! domega_dmsp = merge(0d0,-0.5d0*po2x**(-0.5d0),po2x<po2th.or. isnan(po2x**0.5d0) .or. isnan(po2x**(-0.5d0)))
                ! print *,omega
                ! print *
                ! print *,domega_dmsp
            case default 
                domega_dmsp = 0d0
        endselect 
        
    case('om')
    ! omega is defined so that kpy*poro*hr*mvpy*1d-6*mpyx*(1d0-omega_py) = kpy*poro*hr*mvpy*1d-6*mpyx*po2x**0.5d0
    ! i.e., 1.0 - omega_py = po2x**0.5 
        ! omega = 1d0 - po2x**0.5d0
        omega = 1d0 
        domega_dmsp = 0d0
        ! omega = 0d0
        
    case('omb')
    ! omega is defined so that kpy*poro*hr*mvpy*1d-6*mpyx*(1d0-omega_py) = kpy*poro*hr*mvpy*1d-6*mpyx*po2x**0.5d0
    ! i.e., 1.0 - omega_py = po2x**0.5 
        ! omega = 1d0 - po2x**0.5d0
        omega = 1d0 
        domega_dmsp = 0d0
        ! omega = 0d0
        
        
    case('g1')
    ! omega is defined so that kg1*poro*hr*mvg1*1d-6*mg1x*(1d0-omega_g1) = kg1*poro*hr*mvg1*1d-6*mg1x*po2x/(po2x+mo2)
    ! i.e., 1.0 - omega_g1 = po2x/(po2x+mo2) 
        ! omega = 1d0 
        ! domega_dmsp = 0d0
        ! print *,mineral,sp_name
        omega = 1d0 - po2x/(po2x+mo2g1)&
            & *merge(0d0,1d0,po2x < po2th*thon)
        
        ! omega = 1d0 - po2x/(po2x + keqg1)
        
        select case(trim(adjustl(sp_name)))
            case('po2')
                domega_dmsp = ( &
                    & - 1d0/(po2x + mo2g1) &
                    & - po2x*(-1d0)/(po2x + mo2g1)**2d0 &
                    & ) &
                    & *merge(0d0,1d0,po2x < po2th*thon)
            case default 
                domega_dmsp = 0d0
        endselect 
        
        ! print*, omega
        
        
    case('g2')
    ! omega is defined so that kg2*poro*hr*mvg2*1d-6*mg2x*(1d0-omega_g2) = kg2*poro*hr*mvg2*1d-6*mg2x*po2x/(po2x+mo2)
    ! i.e., 1.0 - omega_g2 = po2x/(po2x+mo2) 
        omega = 1d0 - po2x/(po2x+mo2g2)&
            & *merge(0d0,1d0,po2x < po2th*thon)
        ! print *,mineral,sp_name
        
        
        ! omega = 1d0 
        ! domega_dmsp = 0d0
        
        ! omega = 1d0 - po2x/(po2x + keqg2)
        
        select case(trim(adjustl(sp_name)))
            case('po2')
                domega_dmsp = ( &
                    & - 1d0/(po2x + mo2g2) &
                    & - po2x*(-1d0)/(po2x + mo2g2)**2d0 &
                    & ) &
                    & *merge(0d0,1d0,po2x < po2th*thon)
            case default 
                domega_dmsp = 0d0
        endselect 
        
        ! print*, omega
        
        
    case('g3')
    ! omega is defined so that kg3*poro*hr*mvg3*1d-6*mg3x*(1d0-omega_g3) = kg3*poro*hr*mvg3*1d-6*mg3x*po2x/(po2x+mo2)
    ! i.e., 1.0 - omega_g3 = po2x/(po2x+mo2) 
        omega = 1d0 - po2x/(po2x+mo2g3) &
            & *merge(0d0,1d0,po2x < po2th*thon)
        ! print *,mineral,sp_name
        ! omega = 1d0 
        ! domega_dmsp = 0d0
        
        ! omega = 1d0 - po2x/(po2x + keqg3)
        
        select case(trim(adjustl(sp_name)))
            case('po2')
                domega_dmsp = ( &
                    & - 1d0/(po2x + mo2g3) &
                    & - po2x*(-1d0)/(po2x + mo2g3)**2d0 &
                    & ) &
                    & *merge(0d0,1d0,po2x < po2th*thon)
            case default 
                domega_dmsp = 0d0
        endselect 
        
        ! print*, omega
        
        
    case default 
        ! print *,'non-specified'
        omega = 1d0
        domega_dmsp = 0d0
        ! print *,omega
        
endselect

omega_error = .false.
if (any(isnan(omega)) .or. any(isnan(domega_dmsp))) then 
    print *,'nan in calc_omega_dev_v2',any(isnan(omega)),any(isnan(domega_dmsp)),mineral,sp_name
    omega_error = .true.
    ! stop
endif 

endsubroutine calc_omega_dev_v2

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine calc_omega_v4( &
    & nz,nsp_aq,nsp_gas,nsp_aq_all,nsp_sld_all,nsp_gas_all,nsp_aq_cnst,nsp_gas_cnst & 
    & ,chraq,chraq_cnst,chraq_all,chrsld_all,chrgas,chrgas_cnst,chrgas_all &
    & ,maqx,maqc,mgasx,mgasc,mgasth_all,prox,so4f &
    & ,keqsld_all,keqgas_h,keqaq_h,keqaq_c,keqaq_s,keqaq_no3 &
    & ,staq_all,stgas_all &
    & ,mineral &
    & ,domega_dmaq_all,domega_dmgas_all,domega_dpro_loc,domega_dso4f_loc &! output
    & ,omega,omega_error &! output
    & )
implicit none
integer,intent(in)::nz
real(kind=8):: k1,k2,kco2,po2th,mo2g1,mo2g2,mo2g3,keq_tmp,ss_x,ss_pro,ss_pco2,mo2_tmp
real(kind=8),dimension(nz),intent(in):: prox,so4f
real(kind=8),dimension(nz):: pco2x,po2x
real(kind=8),dimension(nz),intent(out)::omega
logical,intent(out)::omega_error
character(5),intent(in):: mineral

integer,intent(in)::nsp_aq,nsp_gas,nsp_aq_all,nsp_gas_all,nsp_sld_all,nsp_aq_cnst,nsp_gas_cnst
character(5),dimension(nsp_aq),intent(in)::chraq
character(5),dimension(nsp_aq_cnst),intent(in)::chraq_cnst
character(5),dimension(nsp_aq_all),intent(in)::chraq_all
character(5),dimension(nsp_gas),intent(in)::chrgas
character(5),dimension(nsp_gas_cnst),intent(in)::chrgas_cnst
character(5),dimension(nsp_gas_all),intent(in)::chrgas_all
character(5),dimension(nsp_sld_all),intent(in)::chrsld_all
real(kind=8),dimension(nsp_aq,nz),intent(in)::maqx
real(kind=8),dimension(nsp_aq_cnst,nz),intent(in)::maqc
real(kind=8),dimension(nsp_gas,nz),intent(in)::mgasx
real(kind=8),dimension(nsp_gas_cnst,nz),intent(in)::mgasc
real(kind=8),dimension(nsp_gas_all),intent(in)::mgasth_all
real(kind=8),dimension(nsp_gas_all,3),intent(in)::keqgas_h
real(kind=8),dimension(nsp_aq_all,4),intent(in)::keqaq_h
real(kind=8),dimension(nsp_aq_all,2),intent(in)::keqaq_c,keqaq_s,keqaq_no3
real(kind=8),dimension(nsp_sld_all),intent(in)::keqsld_all
real(kind=8),dimension(nsp_sld_all,nsp_aq_all),intent(in)::staq_all
real(kind=8),dimension(nsp_sld_all,nsp_gas_all),intent(in)::stgas_all

real(kind=8),dimension(nz),intent(out)::domega_dpro_loc,domega_dso4f_loc
real(kind=8),dimension(nsp_gas_all,nz),intent(out)::domega_dmgas_all
real(kind=8),dimension(nsp_aq_all,nz),intent(out)::domega_dmaq_all

real(kind=8),dimension(nsp_aq_all,nz)::maqx_loc,maqf_loc
real(kind=8),dimension(nsp_aq_all,nz)::dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2
real(kind=8),dimension(nsp_gas_all,nz)::mgasx_loc

integer ieqgas_h0,ieqgas_h1,ieqgas_h2
data ieqgas_h0,ieqgas_h1,ieqgas_h2/1,2,3/

integer ieqaq_h1,ieqaq_h2,ieqaq_h3,ieqaq_h4
data ieqaq_h1,ieqaq_h2,ieqaq_h3,ieqaq_h4/1,2,3,4/

integer ieqaq_co3,ieqaq_hco3
data ieqaq_co3,ieqaq_hco3/1,2/

integer ieqaq_so4,ieqaq_so42
data ieqaq_so4,ieqaq_so42/1,2/

integer ispa,ipco2,ipo2
! real(kind=8)::thon = 1d0
real(kind=8)::thon = -1d100

mo2g1 = keqsld_all(findloc(chrsld_all,'g1',dim=1))
mo2g2 = keqsld_all(findloc(chrsld_all,'g2',dim=1))
mo2g3 = keqsld_all(findloc(chrsld_all,'g3',dim=1))

po2th = mgasth_all(findloc(chrgas_all,'po2',dim=1))

kco2 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h0)
k1 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h1)
k2 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h2)

call get_maqgasx_all( &
    & nz,nsp_aq_all,nsp_gas_all,nsp_aq,nsp_gas,nsp_aq_cnst,nsp_gas_cnst &
    & ,chraq,chraq_all,chraq_cnst,chrgas,chrgas_all,chrgas_cnst &
    & ,maqx,mgasx,maqc,mgasc &
    & ,maqx_loc,mgasx_loc  &! output
    & )

call get_maqf_all( &
    & nz,nsp_aq_all,nsp_gas_all &
    & ,chraq_all,chrgas_all &
    & ,keqgas_h,keqaq_h,keqaq_c,keqaq_s,keqaq_no3 &
    & ,mgasx_loc,maqx_loc,prox,so4f &
    & ,dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2 &! output
    & ,maqf_loc  &! output
    & )


pco2x = mgasx_loc(findloc(chrgas_all,'pco2',dim=1),:)
po2x = mgasx_loc(findloc(chrgas_all,'po2',dim=1),:)

ipco2 = findloc(chrgas_all,'pco2',dim=1)
ipo2 = findloc(chrgas_all,'po2',dim=1)

domega_dmaq_all =0d0
domega_dmgas_all =0d0
domega_dso4f_loc =0d0
domega_dpro_loc =0d0

select case(trim(adjustl(mineral)))

    ! case default ! (almino)silicates & oxides
    case ( &
        & 'fo','ab','an','ka','gb','ct','fa','gt','cabd','dp','hb','kfs','amsi','hm','ill','anl','nph' &
        & ,'qtz','tm','la','by','olg','and','cpx','en','fer','opx','mgbd','kbd','nabd','mscv','plgp','antp' &
        & ,'agt' &
        & )  ! (almino)silicates & oxides
        keq_tmp = keqsld_all(findloc(chrsld_all,mineral,dim=1))
        omega = 1d0
        ss_pro = 0d0
        do ispa = 1,nsp_aq_all
            if (staq_all(findloc(chrsld_all,mineral,dim=1),ispa) > 0d0) then 

                omega = omega*maqf_loc(ispa,:)**staq_all(findloc(chrsld_all,mineral,dim=1),ispa)
                
                ! derivatives are first given as d(log omega)/dc 
                domega_dmaq_all(ispa,:) = domega_dmaq_all(ispa,:) + ( &
                    & + staq_all(findloc(chrsld_all,mineral,dim=1),ispa)/maqf_loc(ispa,:)*dmaqf_dmaq(ispa,:) &
                    & )
                domega_dmgas_all(ipco2,:) = domega_dmgas_all(ipco2,:) + ( &
                    & + staq_all(findloc(chrsld_all,mineral,dim=1),ispa)/maqf_loc(ispa,:)*dmaqf_dpco2(ispa,:) &
                    & )
                domega_dpro_loc = domega_dpro_loc + ( &
                    & + staq_all(findloc(chrsld_all,mineral,dim=1),ispa)/maqf_loc(ispa,:)*dmaqf_dpro(ispa,:) &
                    & )
                domega_dso4f_loc = domega_dso4f_loc + ( &
                    & + staq_all(findloc(chrsld_all,mineral,dim=1),ispa)/maqf_loc(ispa,:)*dmaqf_dso4f(ispa,:) &
                    & )

                selectcase(trim(adjustl(chraq_all(ispa)))) 
                    case('na','k')
                        ss_pro = ss_pro + staq_all(findloc(chrsld_all,mineral,dim=1),ispa)
                    case('fe2','ca','mg')
                        ss_pro = ss_pro + 2d0*staq_all(findloc(chrsld_all,mineral,dim=1),ispa)
                    case('fe3','al')
                        ss_pro = ss_pro + 3d0*staq_all(findloc(chrsld_all,mineral,dim=1),ispa)
                endselect
            endif 
        enddo 
        
        if (ss_pro > 0d0) then 
            omega = omega / prox**ss_pro

            ! derivatives are first given as d(log omega)/dc 
            domega_dpro_loc = domega_dpro_loc - ss_pro/prox 
        endif 
        
        if (keq_tmp > 0d0) then 
            omega = omega / keq_tmp
        endif         
        
        ! derivatives are now d(omega)/dc ( = d(omega)/d(log omega) * d(log omega)/dc = omega * d(log omega)/dc)
        do ispa=1,nsp_aq_all
            domega_dmaq_all(ispa,:) = domega_dmaq_all(ispa,:)*omega(:)
        enddo 
        domega_dmgas_all(ipco2,:) = domega_dmgas_all(ipco2,:)*omega(:)
        domega_dpro_loc = domega_dpro_loc*omega
        domega_dso4f_loc = domega_dso4f_loc*omega
        
    case('cc','arg','dlm') ! carbonates
        keq_tmp = keqsld_all(findloc(chrsld_all,mineral,dim=1))
        ss_pco2 = stgas_all(findloc(chrsld_all,mineral,dim=1),findloc(chrgas_all,'pco2',dim=1))
        omega = 1d0
        
        do ispa = 1,nsp_aq_all
            if (staq_all(findloc(chrsld_all,mineral,dim=1),ispa) > 0d0) then 
                omega = omega*maqf_loc(ispa,:)**staq_all(findloc(chrsld_all,mineral,dim=1),ispa)
                
                ! derivatives are first given as d(log omega)/dc 
                domega_dmaq_all(ispa,:) = domega_dmaq_all(ispa,:) + ( &
                    & + staq_all(findloc(chrsld_all,mineral,dim=1),ispa)/maqf_loc(ispa,:)*dmaqf_dmaq(ispa,:) &
                    & )
                domega_dmgas_all(ipco2,:) = domega_dmgas_all(ipco2,:) + ( &
                    & + staq_all(findloc(chrsld_all,mineral,dim=1),ispa)/maqf_loc(ispa,:)*dmaqf_dpco2(ispa,:) &
                    & )
                domega_dpro_loc = domega_dpro_loc + ( &
                    & + staq_all(findloc(chrsld_all,mineral,dim=1),ispa)/maqf_loc(ispa,:)*dmaqf_dpro(ispa,:) &
                    & )
                domega_dso4f_loc = domega_dso4f_loc + ( &
                    & + staq_all(findloc(chrsld_all,mineral,dim=1),ispa)/maqf_loc(ispa,:)*dmaqf_dso4f(ispa,:) &
                    & )
            endif 
        enddo 
        
        if (ss_pco2 > 0d0) then
            omega = omega*(k1*k2*kco2*pco2x/(prox**2d0))**ss_pco2
            
            ! derivatives are first given as d(log omega)/dc 
            domega_dmgas_all(ipco2,:) = domega_dmgas_all(ipco2,:) + ss_pco2/pco2x 
            domega_dpro_loc = domega_dpro_loc - 2d0*ss_pco2/prox 
        endif 
        
        if (keq_tmp > 0d0) then 
            omega = omega / keq_tmp
        endif     
        
        ! derivatives are now d(omega)/dc ( = d(omega)/d(log omega) * d(log omega)/dc = omega * d(log omega)/dc)
        do ispa=1,nsp_aq_all
            domega_dmaq_all(ispa,:) = domega_dmaq_all(ispa,:)*omega(:)
        enddo 
        domega_dmgas_all(ipco2,:) = domega_dmgas_all(ipco2,:)*omega(:)
        domega_dpro_loc = domega_dpro_loc*omega
        domega_dso4f_loc = domega_dso4f_loc*omega
        
    case('gps') ! sulfates
    ! CaSO4*2H2O = Ca+2 + SO4-2 + 2H2O
        keq_tmp = keqsld_all(findloc(chrsld_all,mineral,dim=1))
        omega = 1d0
        
        do ispa = 1,nsp_aq_all
            if (staq_all(findloc(chrsld_all,mineral,dim=1),ispa) > 0d0) then 
                omega = omega*maqf_loc(ispa,:)**staq_all(findloc(chrsld_all,mineral,dim=1),ispa)
                
                ! derivatives are first given as d(log omega)/dc 
                domega_dmaq_all(ispa,:) = domega_dmaq_all(ispa,:) + ( &
                    & + staq_all(findloc(chrsld_all,mineral,dim=1),ispa)/maqf_loc(ispa,:)*dmaqf_dmaq(ispa,:) &
                    & )
                domega_dmgas_all(ipco2,:) = domega_dmgas_all(ipco2,:) + ( &
                    & + staq_all(findloc(chrsld_all,mineral,dim=1),ispa)/maqf_loc(ispa,:)*dmaqf_dpco2(ispa,:) &
                    & ) 
                domega_dpro_loc = domega_dpro_loc + ( &
                    & + staq_all(findloc(chrsld_all,mineral,dim=1),ispa)/maqf_loc(ispa,:)*dmaqf_dpro(ispa,:) &
                    & )
                domega_dso4f_loc = domega_dso4f_loc + ( &
                    & + staq_all(findloc(chrsld_all,mineral,dim=1),ispa)/maqf_loc(ispa,:)*dmaqf_dso4f(ispa,:) &
                    & )
            endif 
        enddo 
        
        if (keq_tmp > 0d0) then 
            omega = omega / keq_tmp
        endif     
        
        ! derivatives are now d(omega)/dc ( = d(omega)/d(log omega) * d(log omega)/dc = omega * d(log omega)/dc)
        do ispa=1,nsp_aq_all
            domega_dmaq_all(ispa,:) = domega_dmaq_all(ispa,:)*omega(:)
        enddo 
        domega_dmgas_all(ipco2,:) = domega_dmgas_all(ipco2,:)*omega(:)
        domega_dpro_loc = domega_dpro_loc*omega
        domega_dso4f_loc = domega_dso4f_loc*omega
        
    !!! other minerals that are assumed not to be controlled by distance from equilibrium i.e. omega
    
    case('py') ! sulfides (assumed to be totally controlled by kinetics)
    ! omega is defined so that kpy*poro*hr*mvpy*1d-6*mpyx*(1d0-omega_py) = kpy*poro*hr*mvpy*1d-6*mpyx*po2x**0.5d0
    ! i.e., 1.0 - omega_py = po2x**0.5 
        ! omega = 1d0 - po2x**0.5d0
        omega = 1d0 - po2x**0.5d0*merge(0d0,1d0,po2x<po2th*thon)
        domega_dmgas_all(ipo2,:) = - 0.5d0*po2x**(-0.5d0)*merge(0d0,1d0,po2x<po2th*thon)
        
    case('om','omb')
        omega = 1d0 ! these are not used  
        
    case('g1','g2','g3')
    ! omega is defined so that kg1*poro*hr*mvg1*1d-6*mg1x*(1d0-omega_g1) = kg1*poro*hr*mvg1*1d-6*mg1x*po2x/(po2x+mo2)
    ! i.e., 1.0 - omega_g1 = po2x/(po2x+mo2) 
        if (trim(adjustl(mineral)) == 'g1') mo2_tmp = mo2g1
        if (trim(adjustl(mineral)) == 'g2') mo2_tmp = mo2g2
        if (trim(adjustl(mineral)) == 'g3') mo2_tmp = mo2g3
        omega = 1d0 - po2x/(po2x+mo2_tmp)*merge(0d0,1d0,po2x < po2th*thon)
        domega_dmgas_all(ipo2,:) = ( &
            & - 1d0/(po2x+mo2_tmp)*merge(0d0,1d0,po2x < po2th*thon) &
            & - po2x*(-1d0)/(po2x+mo2_tmp)**2d0*merge(0d0,1d0,po2x < po2th*thon) &
            & )
        
    case default 
        ! this should not be selected
        omega = 1d0
        print *, '*** CAUTION: mineral (',mineral,') saturation state is not defined --- > pause'
        pause
        
endselect

omega_error = .false.
if (any(isnan(omega))) then 
    print *,'nan in calc_omega_v4',any(isnan(omega)),mineral
    omega_error = .true.
    ! stop
endif 

endsubroutine calc_omega_v4

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine get_base_charge( &
    & nsp_aq_all & 
    & ,chraq_all & 
    & ,base_charge &! output 
    & )
implicit none
integer,intent(in)::nsp_aq_all
character(5),dimension(nsp_aq_all),intent(in)::chraq_all
real(kind=8),dimension(nsp_aq_all),intent(out)::base_charge

integer ispa

do ispa = 1, nsp_aq_all
    selectcase(trim(adjustl(chraq_all(ispa))))
        case('so4')
            base_charge(ispa) = -2d0
        case('no3')
            base_charge(ispa) = -1d0
        case('si')
            base_charge(ispa) = 0d0
        case('na','k')
            base_charge(ispa) = 1d0
        case('fe2','mg','ca')
            base_charge(ispa) = 2d0
        case('fe3','al')
            base_charge(ispa) = 3d0
        case default 
            print*,'error in charge assignment'
            stop
    endselect 
enddo
    
endsubroutine get_base_charge

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine get_mgasx_all( &
    & nz,nsp_gas_all,nsp_gas,nsp_gas_cnst &
    & ,chrgas,chrgas_all,chrgas_cnst &
    & ,mgasx,mgasc &
    & ,mgasx_loc  &! output
    & )
implicit none

integer,intent(in)::nz,nsp_gas_all,nsp_gas,nsp_gas_cnst
character(5),dimension(nsp_gas),intent(in)::chrgas
character(5),dimension(nsp_gas_all),intent(in)::chrgas_all
character(5),dimension(nsp_gas_cnst),intent(in)::chrgas_cnst
real(kind=8),dimension(nsp_gas,nz),intent(in)::mgasx
real(kind=8),dimension(nsp_gas_cnst,nz),intent(in)::mgasc

real(kind=8),dimension(nsp_gas_all,nz),intent(out)::mgasx_loc

integer ispg

mgasx_loc = 0d0

do ispg = 1, nsp_gas_all
    if (any(chrgas==chrgas_all(ispg))) then 
        mgasx_loc(ispg,:) =  mgasx(findloc(chrgas,chrgas_all(ispg),dim=1),:)
    elseif (any(chrgas_cnst==chrgas_all(ispg))) then 
        mgasx_loc(ispg,:) =  mgasc(findloc(chrgas_cnst,chrgas_all(ispg),dim=1),:)
    endif 
enddo 


endsubroutine get_mgasx_all

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine get_maqgasx_all( &
    & nz,nsp_aq_all,nsp_gas_all,nsp_aq,nsp_gas,nsp_aq_cnst,nsp_gas_cnst &
    & ,chraq,chraq_all,chraq_cnst,chrgas,chrgas_all,chrgas_cnst &
    & ,maqx,mgasx,maqc,mgasc &
    & ,maqx_loc,mgasx_loc  &! output
    & )
implicit none

integer,intent(in)::nz,nsp_aq_all,nsp_gas_all,nsp_aq,nsp_gas,nsp_aq_cnst,nsp_gas_cnst
character(5),dimension(nsp_aq),intent(in)::chraq
character(5),dimension(nsp_aq_all),intent(in)::chraq_all
character(5),dimension(nsp_aq_cnst),intent(in)::chraq_cnst
character(5),dimension(nsp_gas),intent(in)::chrgas
character(5),dimension(nsp_gas_all),intent(in)::chrgas_all
character(5),dimension(nsp_gas_cnst),intent(in)::chrgas_cnst
real(kind=8),dimension(nsp_aq,nz),intent(in)::maqx
real(kind=8),dimension(nsp_aq_cnst,nz),intent(in)::maqc
real(kind=8),dimension(nsp_gas,nz),intent(in)::mgasx
real(kind=8),dimension(nsp_gas_cnst,nz),intent(in)::mgasc

real(kind=8),dimension(nsp_aq_all,nz),intent(out)::maqx_loc
real(kind=8),dimension(nsp_gas_all,nz),intent(out)::mgasx_loc

integer ispa,ispg

maqx_loc = 0d0
mgasx_loc = 0d0

do ispa = 1, nsp_aq_all
    if (any(chraq==chraq_all(ispa))) then 
        maqx_loc(ispa,:) =  maqx(findloc(chraq,chraq_all(ispa),dim=1),:)
    elseif (any(chraq_cnst==chraq_all(ispa))) then 
        maqx_loc(ispa,:) =  maqc(findloc(chraq_cnst,chraq_all(ispa),dim=1),:)
    endif 
enddo 

do ispg = 1, nsp_gas_all
    if (any(chrgas==chrgas_all(ispg))) then 
        mgasx_loc(ispg,:) =  mgasx(findloc(chrgas,chrgas_all(ispg),dim=1),:)
    elseif (any(chrgas_cnst==chrgas_all(ispg))) then 
        mgasx_loc(ispg,:) =  mgasc(findloc(chrgas_cnst,chrgas_all(ispg),dim=1),:)
    endif 
enddo 


endsubroutine get_maqgasx_all

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine get_maqf_all( &
    & nz,nsp_aq_all,nsp_gas_all &
    & ,chraq_all,chrgas_all &
    & ,keqgas_h,keqaq_h,keqaq_c,keqaq_s,keqaq_no3 &
    & ,mgasx_loc,maqx_loc,prox,so4f &
    & ,dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2 &! output
    & ,maqf_loc  &! output
    & )
implicit none
integer,intent(in)::nz,nsp_aq_all,nsp_gas_all
character(5),dimension(nsp_aq_all),intent(in)::chraq_all
character(5),dimension(nsp_gas_all),intent(in)::chrgas_all
real(kind=8),dimension(nsp_gas_all,3),intent(in)::keqgas_h
real(kind=8),dimension(nsp_aq_all,4),intent(in)::keqaq_h
real(kind=8),dimension(nsp_aq_all,2),intent(in)::keqaq_c,keqaq_s,keqaq_no3
real(kind=8),dimension(nsp_aq_all,nz),intent(in)::maqx_loc
real(kind=8),dimension(nsp_gas_all,nz),intent(in)::mgasx_loc
real(kind=8),dimension(nz),intent(in)::prox,so4f

real(kind=8),dimension(nsp_aq_all,nz),intent(out)::maqf_loc
real(kind=8),dimension(nsp_aq_all,nz),intent(out)::dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2

integer ispa,ispa_h,ispa_c,ispa_s,ispa_no3,ispg

integer ieqgas_h0,ieqgas_h1,ieqgas_h2
data ieqgas_h0,ieqgas_h1,ieqgas_h2/1,2,3/

integer ieqaq_h1,ieqaq_h2,ieqaq_h3,ieqaq_h4
data ieqaq_h1,ieqaq_h2,ieqaq_h3,ieqaq_h4/1,2,3,4/

real(kind=8) kco2,k1,k2,k1no3,rspa_h,rspa_s
real(kind=8),dimension(nz)::pco2x



kco2 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h0)
k1 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h1)
k2 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h2)

pco2x = mgasx_loc(findloc(chrgas_all,'pco2',dim=1),:)

k1no3 = keqaq_h(findloc(chraq_all,'no3',dim=1),ieqaq_h1)

maqf_loc = 0d0

dmaqf_dpro = 0d0
dmaqf_dso4f =0d0
dmaqf_dmaq = 0d0
dmaqf_dpco2 = 0d0

do ispa = 1, nsp_aq_all
    ! annions
    if (trim(adjustl(chraq_all(ispa)))=='no3' .or. trim(adjustl(chraq_all(ispa)))=='so4') then 
        selectcase(trim(adjustl(chraq_all(ispa))))
            case('no3')
                maqf_loc(ispa,:) = 1d0
                if (k1no3 > 0d0) then ! currently NO3 complex with cations are ignored and thus no3f can be calculated analytically
                    maqf_loc(ispa,:) = maqf_loc(ispa,:) + k1no3*prox
                    dmaqf_dpro(ispa,:) = dmaqf_dpro(ispa,:) + k1no3
                endif
                dmaqf_dpro(ispa,:) = maqx_loc(ispa,:)*(-1d0)/maqf_loc(ispa,:)**2d0*dmaqf_dpro(ispa,:)
                dmaqf_dmaq(ispa,:) = 1d0/maqf_loc(ispa,:)
                maqf_loc(ispa,:) = maqx_loc(ispa,:)/maqf_loc(ispa,:)
            case('so4') ! currently SO4 complex with cations are included so that so4f is numerically calculated with pH (or charge balance)
                maqf_loc(ispa,:) = so4f(:)
                dmaqf_dso4f(ispa,:) = 1d0
        endselect
    ! cations
    else 
        maqf_loc(ispa,:) = 1d0
        ! account for hydrolysis speces
        do ispa_h = 1,4
            rspa_h = real(ispa_h,kind=8)
            if ( keqaq_h(ispa,ispa_h) > 0d0) then 
                maqf_loc(ispa,:) = maqf_loc(ispa,:) + keqaq_h(ispa,ispa_h)/prox**rspa_h
                dmaqf_dpro(ispa,:) = dmaqf_dpro(ispa,:) + keqaq_h(ispa,ispa_h)*(-rspa_h)/prox**(1d0+rspa_h)
            endif 
        enddo 
        ! account for species associated with CO3-- (ispa_c =1) and HCO3- (ispa_c =2)
        do ispa_c = 1,2
            if ( keqaq_c(ispa,ispa_c) > 0d0) then 
                if (ispa_c == 1) then ! with CO3--
                    maqf_loc(ispa,:) = maqf_loc(ispa,:) + keqaq_c(ispa,ispa_c)*k1*k2*kco2*pco2x/prox**2d0
                    dmaqf_dpro(ispa,:) = dmaqf_dpro(ispa,:) + keqaq_c(ispa,ispa_c)*k1*k2*kco2*pco2x*(-2d0)/prox**3d0
                    dmaqf_dpco2(ispa,:) = dmaqf_dpco2(ispa,:) + keqaq_c(ispa,ispa_c)*k1*k2*kco2*1d0/prox**2d0
                elseif (ispa_c == 2) then ! with HCO3- ( CO32- + H+)
                    maqf_loc(ispa,:) = maqf_loc(ispa,:) + keqaq_c(ispa,ispa_c)*k1*k2*kco2*pco2x/prox
                    dmaqf_dpro(ispa,:) = dmaqf_dpro(ispa,:) + keqaq_c(ispa,ispa_c)*k1*k2*kco2*pco2x*(-1d0)/prox**2d0
                    dmaqf_dpco2(ispa,:) = dmaqf_dpco2(ispa,:) + keqaq_c(ispa,ispa_c)*k1*k2*kco2*1d0/prox
                endif 
            endif 
        enddo 
        ! account for complexation with free SO4
        do ispa_s = 1,2
            rspa_s = real(ispa_s,kind=8)
            if ( keqaq_s(ispa,ispa_s) > 0d0) then 
                maqf_loc(ispa,:) = maqf_loc(ispa,:) + keqaq_s(ispa,ispa_s)*so4f**rspa_s
                dmaqf_dso4f(ispa,:) = dmaqf_dso4f(ispa,:) + keqaq_s(ispa,ispa_s)*rspa_s*so4f**(rspa_s-1d0)
            endif 
        enddo 
        ! currently NO3 complexation with cations are ignored
        dmaqf_dpro(ispa,:) = maqx_loc(ispa,:)*(-1d0)/maqf_loc(ispa,:)**2d0*dmaqf_dpro(ispa,:)
        dmaqf_dso4f(ispa,:) = maqx_loc(ispa,:)*(-1d0)/maqf_loc(ispa,:)**2d0*dmaqf_dso4f(ispa,:)
        dmaqf_dpco2(ispa,:) = maqx_loc(ispa,:)*(-1d0)/maqf_loc(ispa,:)**2d0*dmaqf_dpco2(ispa,:)
        dmaqf_dmaq(ispa,:) = 1d0/maqf_loc(ispa,:)
        maqf_loc(ispa,:) = maqx_loc(ispa,:)/maqf_loc(ispa,:)
    endif 
enddo     

endsubroutine get_maqf_all

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine calc_rxn_ext_v2( &
    & nz,nrxn_ext_all,nsp_gas_all,nsp_aq_all,nsp_gas,nsp_aq,nsp_aq_cnst,nsp_gas_cnst  &!input
    & ,chrrxn_ext_all,chrgas,chrgas_all,chrgas_cnst,chraq,chraq_all,chraq_cnst &! input
    & ,poro,sat,maqx,maqc,mgasx,mgasc,mgasth_all,maqth_all,krxn1_ext_all,krxn2_ext_all &! input
    & ,nsp_sld,nsp_sld_cnst,chrsld,chrsld_cnst,msldx,msldc,rho_grain &!input
    & ,rxn_name &! input 
    & ,rxn_ext &! output
    & )
implicit none
integer,intent(in)::nz
real(kind=8):: po2th,fe2th,mwtom
real(kind=8),dimension(nz):: po2x,vmax,mo2,fe2x,koxa,vmax2,mom2,komb,beta,omx,ombx
real(kind=8),dimension(nz),intent(in):: poro,sat
real(kind=8),dimension(nz),intent(out):: rxn_ext
character(5),intent(in)::rxn_name

integer,intent(in)::nrxn_ext_all,nsp_gas_all,nsp_aq_all,nsp_gas,nsp_aq,nsp_aq_cnst,nsp_gas_cnst

character(5),dimension(nrxn_ext_all),intent(in)::chrrxn_ext_all
character(5),dimension(nsp_gas),intent(in)::chrgas
character(5),dimension(nsp_gas_all),intent(in)::chrgas_all
character(5),dimension(nsp_gas_cnst),intent(in)::chrgas_cnst
character(5),dimension(nsp_aq),intent(in)::chraq
character(5),dimension(nsp_aq_all),intent(in)::chraq_all
character(5),dimension(nsp_aq_cnst),intent(in)::chraq_cnst

real(kind=8),dimension(nsp_aq,nz),intent(in)::maqx
real(kind=8),dimension(nsp_aq_cnst,nz),intent(in)::maqc
real(kind=8),dimension(nsp_gas,nz),intent(in)::mgasx
real(kind=8),dimension(nsp_gas_cnst,nz),intent(in)::mgasc
real(kind=8),dimension(nsp_gas_all),intent(in)::mgasth_all
real(kind=8),dimension(nsp_aq_all),intent(in)::maqth_all
real(kind=8),dimension(nrxn_ext_all,nz),intent(in)::krxn1_ext_all,krxn2_ext_all

integer,intent(in)::nsp_sld,nsp_sld_cnst

character(5),dimension(nsp_sld),intent(in)::chrsld
character(5),dimension(nsp_sld_cnst),intent(in)::chrsld_cnst

real(kind=8),dimension(nsp_sld,nz),intent(in)::msldx
real(kind=8),dimension(nsp_sld_cnst,nz),intent(in)::msldc

real(kind=8),intent(in)::rho_grain


vmax = krxn1_ext_all(findloc(chrrxn_ext_all,'resp',dim=1),:)
mo2 = krxn2_ext_all(findloc(chrrxn_ext_all,'resp',dim=1),:)

po2th = mgasth_all(findloc(chrgas_all,'po2',dim=1))

koxa = krxn1_ext_all(findloc(chrrxn_ext_all,'fe2o2',dim=1),:) 

fe2th = maqth_all(findloc(chraq_all,'fe2',dim=1))



vmax2 = krxn1_ext_all(findloc(chrrxn_ext_all,'omomb',dim=1),:)
mom2 = krxn2_ext_all(findloc(chrrxn_ext_all,'omomb',dim=1),:)

komb = krxn1_ext_all(findloc(chrrxn_ext_all,'ombto',dim=1),:)
beta = krxn2_ext_all(findloc(chrrxn_ext_all,'ombto',dim=1),:)


po2x = 0d0
if (any(chrgas=='po2')) then 
    po2x = mgasx(findloc(chrgas,'po2',dim=1),:)
elseif (any(chrgas_cnst=='po2')) then 
    po2x = mgasc(findloc(chrgas_cnst,'po2',dim=1),:)
endif 

fe2x = 0d0
if (any(chraq=='fe2')) then 
    fe2x = maqx(findloc(chraq,'fe2',dim=1),:)
elseif (any(chraq_cnst=='fe2')) then 
    fe2x = maqc(findloc(chraq_cnst,'fe2',dim=1),:)
endif 

omx = 0d0
if (any(chrsld=='om')) then 
    omx = msldx(findloc(chrsld,'om',dim=1),:)
elseif (any(chraq_cnst=='om')) then 
    omx = msldc(findloc(chrsld_cnst,'om',dim=1),:)
endif 

ombx = 0d0
if (any(chrsld=='omb')) then 
    ombx = msldx(findloc(chrsld,'omb',dim=1),:)
elseif (any(chraq_cnst=='omb')) then 
    ombx = msldc(findloc(chrsld_cnst,'omb',dim=1),:)
endif 

select case(trim(adjustl(rxn_name)))
    case('resp')
        rxn_ext = vmax*po2x/(po2x+mo2)
        ! rxn_ext = vmax*merge(0d0,po2x/(po2x+mo2),(po2x <po2th).or.(isnan(po2x/(po2x+mo2))))
    case('fe2o2')
        rxn_ext = poro*sat*1d3*koxa*fe2x*po2x &
            & *merge(0d0,1d0,po2x < po2th .or. fe2x < fe2th)
    case('omomb')
        rxn_ext = vmax2 & ! mg C / soil g /yr
            & *omx*(1d0-poro)*rho_grain*1d6*12d0*1d3 &! mol/m3 converted to mg C/ soil g
            & *ombx*(1d0-poro)*rho_grain*1d6*12d0*1d3 &
            & /(mom2 + (omx*(1d0-poro)*rho_grain)*1d6*12d0*1d3) &
            & *1d-3/12d0/((1d0-poro)*rho_grain*1d6) ! converting mg_C/soil_g to mol_C/soil_m3
    case('ombto')
        rxn_ext = komb*(ombx*(1d0-poro)*rho_grain*rho_grain*1d6)**beta &
            & *1d-3/12d0/((1d0-poro)*rho_grain*1d6) ! converting mg_C/soil_g to mol_C/soil_m3
    case default 
        rxn_ext = 0d0
endselect

if (any(isnan(rxn_ext))) then 
    print *,'nan in calc_rxn_ext_v2'
    stop
endif 

endsubroutine calc_rxn_ext_v2

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine calc_rxn_ext_dev_2( &
    & nz,nrxn_ext_all,nsp_gas_all,nsp_aq_all,nsp_gas,nsp_aq,nsp_aq_cnst,nsp_gas_cnst  &!input
    & ,chrrxn_ext_all,chrgas,chrgas_all,chrgas_cnst,chraq,chraq_all,chraq_cnst &! input
    & ,poro,sat,maqx,maqc,mgasx,mgasc,mgasth_all,maqth_all,krxn1_ext_all,krxn2_ext_all &! input
    & ,nsp_sld,nsp_sld_cnst,chrsld,chrsld_cnst,msldx,msldc,rho_grain,kw &!input
    & ,rg,tempk_0,tc &!input
    & ,nsp_sld_all,chrsld_all,msldth_all,mv_all,hr,prox,keqgas_h,keqaq_h,keqaq_c,keqaq_s,so4f &! input
    & ,rxn_name,sp_name &! input 
    & ,rxn_ext,drxnext_dmsp,rxnext_error &! output
    & )
implicit none
integer,intent(in)::nz
real(kind=8):: po2th,fe2th,mwtom,g1th,g2th,g3th,mvpy,fe3th,knh3,k1nh3,ko2,v_tmp,km_tmp1,km_tmp2,km_tmp3  &
    & ,kn2o,k1fe2,k1fe2co3,k1fe2hco3,k1fe2so4,kco2,k1,k2
real(kind=8),dimension(nz):: po2x,vmax,mo2,fe2x,koxa,vmax2,mom2,komb,beta,omx,ombx &
    & ,mo2g1,mo2g2,mo2g3,kg1,kg2,kg3,g1x,g2x,g3x,pyx,fe3x,koxpy,pnh3x,nh4x,dnh4_dpro,dnh4_dpnh3 &
    & ,no3x,pn2ox,dv_dph_tmp,fe2f,dfe2f_dfe2,dfe2f_dpco2,dfe2f_dpro,dfe2f_dso4f,pco2x
real(kind=8),dimension(nz),intent(in):: poro,sat,hr,prox,so4f
real(kind=8),dimension(nz),intent(out):: drxnext_dmsp
real(kind=8),dimension(nz),intent(out):: rxn_ext
character(5),intent(in)::rxn_name,sp_name
logical,intent(out)::rxnext_error

integer,intent(in)::nrxn_ext_all,nsp_gas_all,nsp_aq_all,nsp_gas,nsp_aq,nsp_aq_cnst,nsp_gas_cnst 

character(5),dimension(nrxn_ext_all),intent(in)::chrrxn_ext_all
character(5),dimension(nsp_gas),intent(in)::chrgas
character(5),dimension(nsp_gas_all),intent(in)::chrgas_all
character(5),dimension(nsp_gas_cnst),intent(in)::chrgas_cnst
character(5),dimension(nsp_aq),intent(in)::chraq
character(5),dimension(nsp_aq_all),intent(in)::chraq_all
character(5),dimension(nsp_aq_cnst),intent(in)::chraq_cnst

real(kind=8),dimension(nsp_aq,nz),intent(in)::maqx
real(kind=8),dimension(nsp_aq_cnst,nz),intent(in)::maqc
real(kind=8),dimension(nsp_gas,nz),intent(in)::mgasx
real(kind=8),dimension(nsp_gas_cnst,nz),intent(in)::mgasc
real(kind=8),dimension(nsp_gas_all),intent(in)::mgasth_all
real(kind=8),dimension(nsp_gas_all,3),intent(in)::keqgas_h
real(kind=8),dimension(nsp_aq_all),intent(in)::maqth_all
real(kind=8),dimension(nsp_aq_all,4),intent(in)::keqaq_h
real(kind=8),dimension(nsp_aq_all,2),intent(in)::keqaq_c,keqaq_s
real(kind=8),dimension(nrxn_ext_all,nz),intent(in)::krxn1_ext_all,krxn2_ext_all

integer,intent(in)::nsp_sld,nsp_sld_cnst,nsp_sld_all

character(5),dimension(nsp_sld),intent(in)::chrsld
character(5),dimension(nsp_sld_cnst),intent(in)::chrsld_cnst
character(5),dimension(nsp_sld_all),intent(in)::chrsld_all

real(kind=8),dimension(nsp_sld,nz),intent(in)::msldx
real(kind=8),dimension(nsp_sld_cnst,nz),intent(in)::msldc
real(kind=8),dimension(nsp_sld_all),intent(in)::msldth_all,mv_all

real(kind=8),intent(in)::rho_grain,kw,rg,tempk_0,tc

! real(kind=8):: thon = 1d0
real(kind=8):: thon = -1d100

integer ieqgas_h0,ieqgas_h1,ieqgas_h2
data ieqgas_h0,ieqgas_h1,ieqgas_h2/1,2,3/

integer ieqaq_h1,ieqaq_h2,ieqaq_h3,ieqaq_h4
data ieqaq_h1,ieqaq_h2,ieqaq_h3,ieqaq_h4/1,2,3,4/

integer ieqaq_co3,ieqaq_hco3
data ieqaq_co3,ieqaq_hco3/1,2/

integer ieqaq_so4,ieqaq_so42
data ieqaq_so4,ieqaq_so42/1,2/

character(25) scheme

vmax = krxn1_ext_all(findloc(chrrxn_ext_all,'resp',dim=1),:)
mo2 = krxn2_ext_all(findloc(chrrxn_ext_all,'resp',dim=1),:)

po2th = mgasth_all(findloc(chrgas_all,'po2',dim=1))

koxa = krxn1_ext_all(findloc(chrrxn_ext_all,'fe2o2',dim=1),:) 

fe2th = maqth_all(findloc(chraq_all,'fe2',dim=1))

fe3th = maqth_all(findloc(chraq_all,'fe3',dim=1))

g1th = msldth_all(findloc(chrsld_all,'g1',dim=1))
g2th = msldth_all(findloc(chrsld_all,'g2',dim=1))
g3th = msldth_all(findloc(chrsld_all,'g3',dim=1))

ko2 = keqgas_h(findloc(chrgas_all,'po2',dim=1),ieqgas_h0)

kco2 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h0)
k1 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h1)
k2 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h1)

knh3 = keqgas_h(findloc(chrgas_all,'pnh3',dim=1),ieqgas_h0)
k1nh3 = keqgas_h(findloc(chrgas_all,'pnh3',dim=1),ieqgas_h1)

kn2o = keqgas_h(findloc(chrgas_all,'pn2o',dim=1),ieqgas_h0)

k1fe2 = keqaq_h(findloc(chraq_all,'fe2',dim=1),ieqaq_h1)
k1fe2co3 = keqaq_c(findloc(chraq_all,'fe2',dim=1),ieqaq_co3)
k1fe2hco3  = keqaq_c(findloc(chraq_all,'fe2',dim=1),ieqaq_hco3)
k1fe2so4 = keqaq_s(findloc(chraq_all,'fe2',dim=1),ieqaq_so4)

vmax2 = krxn1_ext_all(findloc(chrrxn_ext_all,'omomb',dim=1),:)
mom2 = krxn2_ext_all(findloc(chrrxn_ext_all,'omomb',dim=1),:)

komb = krxn1_ext_all(findloc(chrrxn_ext_all,'ombto',dim=1),:)
beta = krxn2_ext_all(findloc(chrrxn_ext_all,'ombto',dim=1),:)

koxpy = krxn1_ext_all(findloc(chrrxn_ext_all,'pyfe3',dim=1),:)

po2x = 0d0
if (any(chrgas=='po2')) then 
    po2x = mgasx(findloc(chrgas,'po2',dim=1),:)
elseif (any(chrgas_cnst=='po2')) then 
    po2x = mgasc(findloc(chrgas_cnst,'po2',dim=1),:)
endif 

pco2x = 0d0
if (any(chrgas=='pco2')) then 
    pco2x = mgasx(findloc(chrgas,'pco2',dim=1),:)
elseif (any(chrgas_cnst=='pco2')) then 
    pco2x = mgasc(findloc(chrgas_cnst,'pco2',dim=1),:)
endif 

pnh3x = 0d0
if (any(chrgas=='pnh3')) then 
    pnh3x = mgasx(findloc(chrgas,'pnh3',dim=1),:)
elseif (any(chrgas_cnst=='pnh3')) then 
    pnh3x = mgasc(findloc(chrgas_cnst,'pnh3',dim=1),:)
endif 
nh4x = pnh3x*knh3*prox/k1nh3
dnh4_dpro = pnh3x*knh3*1d0/k1nh3
dnh4_dpnh3 = 1d0*knh3*prox/k1nh3

pn2ox = 0d0
if (any(chrgas=='pn2o')) then 
    pn2ox = mgasx(findloc(chrgas,'pn2o',dim=1),:)
elseif (any(chrgas_cnst=='pn2o')) then 
    pn2ox = mgasc(findloc(chrgas_cnst,'pn2o',dim=1),:)
endif 

fe2x = 0d0
if (any(chraq=='fe2')) then 
    fe2x = maqx(findloc(chraq,'fe2',dim=1),:)
elseif (any(chraq_cnst=='fe2')) then 
    fe2x = maqc(findloc(chraq_cnst,'fe2',dim=1),:)
endif 
    
fe2f = fe2x/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox+k1fe2so4*so4f)
dfe2f_dfe2 = 1d0/(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox+k1fe2so4*so4f)
dfe2f_dpro = fe2x*(-1d0) &
    & /(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox+k1fe2so4*so4f)**2d0 &
    & *(k1fe2*(-1d0)/prox**2d0+k1fe2co3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0+k1fe2hco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0)
dfe2f_dpco2 = fe2x*(-1d0) &
    & /(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox+k1fe2so4*so4f)**2d0 &
    & *(k1fe2co3*k1*k2*kco2*1d0/prox**2d0+k1fe2hco3*k1*k2*kco2*1d0/prox)
dfe2f_dso4f = fe2x*(-1d0) &
    & /(1d0+k1fe2/prox+k1fe2co3*k1*k2*kco2*pco2x/prox**2d0+k1fe2hco3*k1*k2*kco2*pco2x/prox+k1fe2so4*so4f)**2d0 &
    & * k1fe2so4

fe3x = 0d0
if (any(chraq=='fe3')) then 
    fe3x = maqx(findloc(chraq,'fe3',dim=1),:)
elseif (any(chraq_cnst=='fe3')) then 
    fe3x = maqc(findloc(chraq_cnst,'fe3',dim=1),:)
endif 

no3x = 0d0
if (any(chraq=='no3')) then 
    no3x = maqx(findloc(chraq,'no3',dim=1),:)
elseif (any(chraq_cnst=='no3')) then 
    no3x = maqc(findloc(chraq_cnst,'no3',dim=1),:)
endif 

omx = 0d0
if (any(chrsld=='om')) then 
    omx = msldx(findloc(chrsld,'om',dim=1),:)
elseif (any(chraq_cnst=='om')) then 
    omx = msldc(findloc(chrsld_cnst,'om',dim=1),:)
endif 

ombx = 0d0
if (any(chrsld=='omb')) then 
    ombx = msldx(findloc(chrsld,'omb',dim=1),:)
elseif (any(chraq_cnst=='omb')) then 
    ombx = msldc(findloc(chrsld_cnst,'omb',dim=1),:)
endif 

g1x = 0d0
if (any(chrsld=='g1')) then 
    g1x = msldx(findloc(chrsld,'g1',dim=1),:)
elseif (any(chraq_cnst=='g1')) then 
    g1x = msldc(findloc(chrsld_cnst,'g1',dim=1),:)
endif 

g2x = 0d0
if (any(chrsld=='g2')) then 
    g2x = msldx(findloc(chrsld,'g2',dim=1),:)
elseif (any(chraq_cnst=='g2')) then 
    g2x = msldc(findloc(chrsld_cnst,'g2',dim=1),:)
endif 

g3x = 0d0
if (any(chrsld=='g3')) then 
    g3x = msldx(findloc(chrsld,'g3',dim=1),:)
elseif (any(chraq_cnst=='g3')) then 
    g3x = msldc(findloc(chrsld_cnst,'g3',dim=1),:)
endif 

pyx = 0d0
if (any(chrsld=='py')) then 
    pyx = msldx(findloc(chrsld,'py',dim=1),:)
elseif (any(chraq_cnst=='py')) then 
    pyx = msldc(findloc(chrsld_cnst,'py',dim=1),:)
endif 

mvpy = mv_all(findloc(chrsld_all,'py',dim=1))

select case(trim(adjustl(rxn_name)))

    case('resp')
        rxn_ext = vmax*po2x/(po2x+mo2)
        ! rxn_ext = vmax*merge(0d0,po2x/(po2x+mo2),(po2x <po2th).or.(isnan(po2x/(po2x+mo2))))
        
        select case(trim(adjustl(sp_name)))
            case('po2')
                drxnext_dmsp = (&
                    & vmax*1d0/(po2x+mo2) &
                    & +vmax*po2x*(-1d0)/(po2x+mo2)**2d0 &
                    & )
            case default
                drxnext_dmsp = 0d0
        endselect 
        
    case('fe2o2')
        ! scheme = 'full' ! reflecting individual rate consts for different Fe2+ species (after Kanzaki and Murakami 2016)
        scheme = 'default' ! as a function of pH and pO2
        
        selectcase(trim(adjustl(scheme)))
            case('full')
                rxn_ext = ( &
                    & + poro*sat*1d3*fe2f*( &
                    & + k_arrhenius(10d0**(1.46d0),25d0+tempk_0,tc+tempk_0,46d0,rg) &
                    & + k_arrhenius(10d0**(8.34d0),25d0+tempk_0,tc+tempk_0,21.6d0,rg)*k1fe2/prox &
                    & + k_arrhenius(10d0**(6.27d0),25d0+tempk_0,tc+tempk_0,29d0,rg)*k1fe2co3*k1*k2*kco2*pco2x/prox**2d0 &
                    & + k_arrhenius(10d0**(5.12d0),25d0+tempk_0,tc+tempk_0,29d0,rg)*k1fe2hco3*k1*k2*kco2*pco2x/prox &
                    & )*po2x &
                    & )
                
                select case(trim(adjustl(sp_name)))
                    case('pro')
                        drxnext_dmsp = ( &
                            & + poro*sat*1d3*dfe2f_dpro*( &
                            & + k_arrhenius(10d0**(1.46d0),25d0+tempk_0,tc+tempk_0,46d0,rg) &
                            & + k_arrhenius(10d0**(8.34d0),25d0+tempk_0,tc+tempk_0,21.6d0,rg)*k1fe2/prox &
                            & + k_arrhenius(10d0**(6.27d0),25d0+tempk_0,tc+tempk_0,29d0,rg)*k1fe2co3*k1*k2*kco2*pco2x/prox**2d0 &
                            & + k_arrhenius(10d0**(5.12d0),25d0+tempk_0,tc+tempk_0,29d0,rg)*k1fe2hco3*k1*k2*kco2*pco2x/prox &
                            & )*po2x &
                            & + poro*sat*1d3*fe2f*( &
                            & + k_arrhenius(10d0**(8.34d0),25d0+tempk_0,tc+tempk_0,21.6d0,rg)*k1fe2*(-1d0)/prox**2d0 &
                            & + k_arrhenius(10d0**(6.27d0),25d0+tempk_0,tc+tempk_0,29d0,rg) &
                            &       *k1fe2co3*k1*k2*kco2*pco2x*(-2d0)/prox**3d0 &
                            & + k_arrhenius(10d0**(5.12d0),25d0+tempk_0,tc+tempk_0,29d0,rg) &
                            &       *k1fe2hco3*k1*k2*kco2*pco2x*(-1d0)/prox**2d0 &
                            & )*po2x &
                            & )
                    case('so4f')
                        drxnext_dmsp = ( &
                            & + poro*sat*1d3*dfe2f_dso4f*( &
                            & + k_arrhenius(10d0**(1.46d0),25d0+tempk_0,tc+tempk_0,46d0,rg) &
                            & + k_arrhenius(10d0**(8.34d0),25d0+tempk_0,tc+tempk_0,21.6d0,rg)*k1fe2/prox &
                            & + k_arrhenius(10d0**(6.27d0),25d0+tempk_0,tc+tempk_0,29d0,rg)*k1fe2co3*k1*k2*kco2*pco2x/prox**2d0 &
                            & + k_arrhenius(10d0**(5.12d0),25d0+tempk_0,tc+tempk_0,29d0,rg)*k1fe2hco3*k1*k2*kco2*pco2x/prox &
                            & )*po2x &
                            & )
                    case('po2')
                        drxnext_dmsp = ( &
                            & + poro*sat*1d3*fe2f*( &
                            & + k_arrhenius(10d0**(1.46d0),25d0+tempk_0,tc+tempk_0,46d0,rg) &
                            & + k_arrhenius(10d0**(8.34d0),25d0+tempk_0,tc+tempk_0,21.6d0,rg)*k1fe2/prox &
                            & + k_arrhenius(10d0**(6.27d0),25d0+tempk_0,tc+tempk_0,29d0,rg)*k1fe2co3*k1*k2*kco2*pco2x/prox**2d0 &
                            & + k_arrhenius(10d0**(5.12d0),25d0+tempk_0,tc+tempk_0,29d0,rg)*k1fe2hco3*k1*k2*kco2*pco2x/prox &
                            & )*1d0 &
                            & )
                    case('pco2')
                        drxnext_dmsp = ( &
                            & + poro*sat*1d3*dfe2f_dpco2*( &
                            & + k_arrhenius(10d0**(1.46d0),25d0+tempk_0,tc+tempk_0,46d0,rg) &
                            & + k_arrhenius(10d0**(8.34d0),25d0+tempk_0,tc+tempk_0,21.6d0,rg)*k1fe2/prox &
                            & + k_arrhenius(10d0**(6.27d0),25d0+tempk_0,tc+tempk_0,29d0,rg)*k1fe2co3*k1*k2*kco2*pco2x/prox**2d0 &
                            & + k_arrhenius(10d0**(5.12d0),25d0+tempk_0,tc+tempk_0,29d0,rg)*k1fe2hco3*k1*k2*kco2*pco2x/prox &
                            & )*po2x &
                            & + poro*sat*1d3*fe2f*( &
                            & + k_arrhenius(10d0**(6.27d0),25d0+tempk_0,tc+tempk_0,29d0,rg)*k1fe2co3*k1*k2*kco2*1d0/prox**2d0 &
                            & + k_arrhenius(10d0**(5.12d0),25d0+tempk_0,tc+tempk_0,29d0,rg)*k1fe2hco3*k1*k2*kco2*1d0/prox &
                            & )*po2x &
                            & )
                    case('fe2')
                        drxnext_dmsp = ( &
                            & + poro*sat*1d3*dfe2f_dfe2*( &
                            & + k_arrhenius(10d0**(1.46d0),25d0+tempk_0,tc+tempk_0,46d0,rg) &
                            & + k_arrhenius(10d0**(8.34d0),25d0+tempk_0,tc+tempk_0,21.6d0,rg)*k1fe2/prox &
                            & + k_arrhenius(10d0**(6.27d0),25d0+tempk_0,tc+tempk_0,29d0,rg)*k1fe2co3*k1*k2*kco2*pco2x/prox**2d0 &
                            & + k_arrhenius(10d0**(5.12d0),25d0+tempk_0,tc+tempk_0,29d0,rg)*k1fe2hco3*k1*k2*kco2*pco2x/prox &
                            & )*po2x &
                            & )
                    case default
                        drxnext_dmsp = 0d0
                endselect
                
            case default
                rxn_ext = ( &
                    & poro*sat*1d3*fe2x*po2x &
                    & *(8.0d13*60.0d0*24.0d0*365.0d0*(kw/prox)**2.0d0 + 1d-7*60.0d0*24.0d0*365.0d0) &
                    & *merge(0d0,1d0,po2x < po2th*thon .or. fe2x < fe2th*thon) &
                    & )
                
                select case(trim(adjustl(sp_name)))
                    case('pro')
                        drxnext_dmsp = ( &
                            & poro*sat*1d3*fe2x*po2x &
                            & *(8.0d13*60.0d0*24.0d0*365.0d0*(kw/prox)*2.0d0*(kw*(-1d0)/prox**2d0)) &
                            & *merge(0d0,1d0,po2x < po2th*thon .or. fe2x < fe2th*thon) &
                            & )
                    case('po2')
                        drxnext_dmsp = ( &
                            & poro*sat*1d3*fe2x*1d0 &
                            & *(8.0d13*60.0d0*24.0d0*365.0d0*(kw/prox)**2.0d0 + 1d-7*60.0d0*24.0d0*365.0d0) &
                            & *merge(0d0,1d0,po2x < po2th*thon .or. fe2x < fe2th*thon) &
                            & )
                    case('fe2')
                        drxnext_dmsp = ( &
                            & poro*sat*1d3*1d0*po2x &
                            & *(8.0d13*60.0d0*24.0d0*365.0d0*(kw/prox)**2.0d0 + 1d-7*60.0d0*24.0d0*365.0d0) &
                            & *merge(0d0,1d0,po2x < po2th*thon .or. fe2x < fe2th*thon) &
                            & )
                    case default
                        drxnext_dmsp = 0d0
                endselect
        endselect 
    
    case('omomb')
        rxn_ext = vmax2 & ! mg C / soil g /yr
            & *omx*(1d0-poro)*rho_grain*1d6*12d0*1d3 &! mol/m3 converted to mg C/ soil g
            & *ombx*(1d0-poro)*rho_grain*1d6*12d0*1d3 &
            & /(mom2 + (omx*(1d0-poro)*rho_grain)*1d6*12d0*1d3) &
            & *1d-3/12d0/((1d0-poro)*rho_grain*1d6) ! converting mg_C/soil_g to mol_C/soil_m3
        
        select case(trim(adjustl(sp_name)))
            case('om')
                drxnext_dmsp = ( &
                    & vmax2 & ! mg C / soil g /yr
                    & *1d0*(1d0-poro)*rho_grain*1d6*12d0*1d3 &! mol/m3 converted to mg C/ soil g
                    & *ombx*(1d0-poro)*rho_grain*1d6*12d0*1d3 &
                    & /(mom2 + (omx*(1d0-poro)*rho_grain)*1d6*12d0*1d3) &
                    & *1d-3/12d0/((1d0-poro)*rho_grain*1d6) &! converting mg_C/soil_g to mol_C/soil_m3
                    & + vmax2 & ! mg C / soil g /yr
                    & *omx*(1d0-poro)*rho_grain*1d6*12d0*1d3 &! mol/m3 converted to mg C/ soil g
                    & *ombx*(1d0-poro)*rho_grain*1d6*12d0*1d3 &
                    & *(-1d0)/(mom2 + (omx*(1d0-poro)*rho_grain)*1d6*12d0*1d3)**2d0 &
                    & *(1d0-poro)*rho_grain*1d6*12d0*1d3 &
                    & *1d-3/12d0/((1d0-poro)*rho_grain*1d6) &! converting mg_C/soil_g to mol_C/soil_m3
                    & ) 
            case('omb')
                drxnext_dmsp = ( &
                    & vmax2 & ! mg C / soil g /yr
                    & *omx*(1d0-poro)*rho_grain*1d6*12d0*1d3 &! mol/m3 converted to mg C/ soil g
                    & *1d0*(1d0-poro)*rho_grain*1d6*12d0*1d3 &
                    & /(mom2 + (omx*(1d0-poro)*rho_grain)*1d6*12d0*1d3) &
                    & *1d-3/12d0/((1d0-poro)*rho_grain*1d6) &! converting mg_C/soil_g to mol_C/soil_m3
                    & ) 
            case default
                drxnext_dmsp = 0d0
        endselect
    
    case('ombto')
        rxn_ext = komb*(ombx*(1d0-poro)*rho_grain*rho_grain*1d6)**beta &
            & *1d-3/12d0/((1d0-poro)*rho_grain*1d6) ! converting mg_C/soil_g to mol_C/soil_m3
        
        select case(trim(adjustl(sp_name)))
            case('omb')
                drxnext_dmsp = ( &
                    & komb*beta*(ombx*(1d0-poro)*rho_grain*rho_grain*1d6)**(beta-1d0) &
                    & *(1d0-poro)*rho_grain*rho_grain*1d6 &
                    & *1d-3/12d0/((1d0-poro)*rho_grain*1d6) &! converting mg_C/soil_g to mol_C/soil_m3
                    & ) 
    
            case default
                drxnext_dmsp = 0d0
                
        endselect 
                
    
    case('pyfe3') 
        rxn_ext = ( &
            & koxpy*poro*hr*mvpy*pyx*fe3x**0.93d0*fe2x**(-0.40d0) &
            & *merge(0d0,1d0,fe3x<fe3th*thon .or. fe2x<fe2th*thon) &
            & /(1d0 - poro) &
            & )
        
        select case(trim(adjustl(sp_name)))
            case('py')
                drxnext_dmsp = (&
                    & koxpy*poro*hr*mvpy*1d0*fe3x**0.93d0*fe2x**(-0.40d0) &
                    & *merge(0d0,1d0,fe3x<fe3th*thon .or. fe2x<fe2th*thon) &
                    & )
            case('fe3')
                drxnext_dmsp = (&
                    & koxpy*poro*hr*mvpy*pyx*(0.93d0)*fe3x**(0.93d0-1d0)*fe2x**(-0.40d0) &
                    & *merge(0d0,1d0,fe3x<fe3th*thon .or. fe2x<fe2th*thon) &
                    & )
            case('fe2')
                drxnext_dmsp = (&
                    & koxpy*poro*hr*mvpy*pyx*fe3x**0.93d0*(-0.4d0)*fe2x**(-0.40d0-1d0) &
                    & *merge(0d0,1d0,fe3x<fe3th*thon .or. fe2x<fe2th*thon) &
                    & )
            case default
                drxnext_dmsp = 0d0
        endselect 
        
    case('amo2o')
        scheme = 'maggi08' ! Maggi et al. (2008) wihtout baterial, pH and water saturation functions
        ! scheme = 'Fennel' ! from biogem_box_geochem.f90 in GENIE model referring to Fennel et al. 2005 with a correction 
        ! scheme = 'FennelOLD' ! from biogem_box_geochem.f90 in GENIE model referring to Fennel et al. 2005 without a correction 
        ! scheme = 'Ozaki' ! from biogem_box_geochem.f90 in GENIE model referring to Ozaki et al. [EPSL ... ?]
        
        select case(trim(adjustl(scheme)))
            case('maggi08')
                v_tmp = 9.53d-6*60d0*60d0*24d0*365d0 ! (~300 /yr)
                ! v_tmp = v_tmp/100d0 ! (~3 /yr; default value produces too much nitrate (pH goes down to ~1)
                km_tmp1 = 14d-5
                km_tmp2 = 2.41d-5
                rxn_ext = ( &
                    & v_tmp &
                    & *nh4x/(nh4x + km_tmp1 ) &
                    & *po2x*ko2/(po2x*ko2 + km_tmp2 ) &
                    & *min(2d0*sat,1d0) &
                    ! & *max( min( 0.25d0*(-log10(prox))-0.75d0, -0.25d0*(-log10(prox))+2.75d0 ), 0d0 ) &
                    & *exp(-0.5d0*((-log10(prox)-7d0)/1d0)**2d0) &! modified version using normal distribution with sigma = 1 
                    & )
                
                dv_dph_tmp = 0d0
                where (3d0 < -log10(prox) .and. -log10(prox) < 7d0)
                    dv_dph_tmp = 0.25d0
                elsewhere (7d0 < -log10(prox) .and. -log10(prox) < 11d0)
                    dv_dph_tmp = -0.25d0
                elsewhere (-log10(prox) == 7d0)
                    dv_dph_tmp = 0d0
                elsewhere (-log10(prox) == 3d0)
                    dv_dph_tmp = 0.125d0
                elsewhere (-log10(prox) == 11d0)
                    dv_dph_tmp = -0.125d0
                elsewhere 
                    dv_dph_tmp = 0d0
                endwhere 
                
                ! when using modified version using normal distribution with sigma = 1 
                dv_dph_tmp = exp(-0.5d0*((-log10(prox)-7d0)/1d0)**2d0) &
                    & *-0.5d0*2d0*((-log10(prox)-7d0)/1d0)  &
                    & *(-1d0) &
                    & *1d0/log(10d0)/prox
                
                select case(trim(adjustl(sp_name)))
                    case('po2')
                        drxnext_dmsp = ( &
                            & v_tmp &
                            & *nh4x/(nh4x + km_tmp1 ) &
                            & *( &
                            & 1d0*ko2/(po2x*ko2 + km_tmp2) &
                            & + po2x*ko2*(-1d0)/(po2x*ko2 + km_tmp2)**2d0 * ko2 &
                            & ) &
                            & *min(2d0*sat,1d0) &
                            ! & *max( min( 0.25d0*(-log10(prox))-0.75d0, -0.25d0*(-log10(prox))+2.75d0 ), 0d0 ) &
                            & *exp(-0.5d0*((-log10(prox)-7d0)/1d0)**2d0) &! modified version using normal distribution with sigma = 1 
                            & )
                    case('pnh3')
                        drxnext_dmsp = ( &
                            & v_tmp &
                            & * ( & 
                            & dnh4_dpnh3/(nh4x + km_tmp1 ) &
                            & + nh4x*(-1d0)/(nh4x + km_tmp1 )**2d0 * dnh4_dpnh3 &
                            & ) &
                            & *po2x*ko2/(po2x*ko2 + km_tmp2) &
                            & *min(2d0*sat,1d0) &
                            ! & *max( min( 0.25d0*(-log10(prox))-0.75d0, -0.25d0*(-log10(prox))+2.75d0 ), 0d0 ) &
                            & *exp(-0.5d0*((-log10(prox)-7d0)/1d0)**2d0) &! modified version using normal distribution with sigma = 1 
                            & )
                    case('pro')
                        drxnext_dmsp = ( &
                            & v_tmp &
                            & * ( & 
                            & dnh4_dpro/(nh4x + km_tmp1 ) &
                            & + nh4x*(-1d0)/(nh4x + km_tmp1 )**2d0 * dnh4_dpro &
                            & ) &
                            & *po2x*ko2/(po2x*ko2 + km_tmp2) &
                            & *min(2d0*sat,1d0) &
                            ! & *max( min( 0.25d0*(-log10(prox))-0.75d0, -0.25d0*(-log10(prox))+2.75d0 ), 0d0 ) &
                            & *exp(-0.5d0*((-log10(prox)-7d0)/1d0)**2d0) &! modified version using normal distribution with sigma = 1 
                            & + &
                            & v_tmp &
                            & *nh4x/(nh4x + km_tmp1 ) &
                            & *po2x*ko2/(po2x*ko2 + km_tmp2 ) &
                            & *min(2d0*sat,1d0) &
                            & *dv_dph_tmp &
                            & )
                    case default
                        drxnext_dmsp = 0d0
                endselect 
                
            case('Fennel','FennelOLD')
                if (trim(adjustl(scheme))== 'Fennel') v_tmp = 6.0d0 ! /yr
                if (trim(adjustl(scheme))== 'FennelOLD') v_tmp = 0.16667d0 ! /yr
                km_tmp2 = 2.0D-05
                rxn_ext = ( &
                    & v_tmp &
                    & *nh4x &
                    & *po2x*ko2/(po2x*ko2 + km_tmp2 ) &
                    & )
                
                select case(trim(adjustl(sp_name)))
                    case('po2')
                        drxnext_dmsp = ( &
                            & v_tmp &
                            & *nh4x &
                            & *( &
                            & 1d0*ko2/(po2x*ko2 + km_tmp2) &
                            & + po2x*ko2*(-1d0)/(po2x*ko2 + km_tmp2)**2d0 * ko2 &
                            & ) &
                            & )
                    case('pnh3')
                        drxnext_dmsp = ( &
                            & v_tmp &
                            & *dnh4_dpnh3 &
                            & *po2x*ko2/(po2x*ko2 + km_tmp2) &
                            & )
                    case('pro')
                        drxnext_dmsp = ( &
                            & v_tmp &
                            & * dnh4_dpro &
                            & *po2x*ko2/(po2x*ko2 + km_tmp2) &
                            & )
                    case default
                        drxnext_dmsp = 0d0
                endselect 
                
            case('Ozaki')
                v_tmp = 18250.0d0/1027.649d0 ! /yr
                rxn_ext = ( &
                    & v_tmp &
                    & *nh4x &
                    & *po2x*ko2 &
                    & )
                
                select case(trim(adjustl(sp_name)))
                    case('po2')
                        drxnext_dmsp = ( &
                            & v_tmp &
                            & *nh4x &
                            & * 1d0*ko2 &
                            & )
                    case('pnh3')
                        drxnext_dmsp = ( &
                            & v_tmp &
                            & *dnh4_dpnh3 &
                            & *po2x*ko2 &
                            & )
                    case('pro')
                        drxnext_dmsp = ( &
                            & v_tmp &
                            & * dnh4_dpro &
                            & *po2x*ko2 &
                            & )
                    case default
                        drxnext_dmsp = 0d0
                endselect 
                
            endselect
                
    case('g2n0','g2n21') 
        ! overall denitrification (4 NO3-  +  5 CH2O  +  4 H+  ->  2 N2  +  5 CO2  +  7 H2O) 
        ! first of 2 step denitrification (2 NO3-  +  2 CH2O  +  2 H+  ->  N2O  +  2 CO2  +  3 H2O)   
        ! (assuming that oxidation by N2O governs overall denitrification)
        scheme = 'maggi08' ! Maggi et al. (2008) wihtout baterial, pH and water saturation functions; vmax from oxidation by N2O (rate-limiting)
        
        select case(trim(adjustl(scheme)))
            case('maggi08')
                v_tmp = 1.23d-7*60d0*60d0*24d0*365d0
                km_tmp1 = 10d-5 * 1d6 ! mol L-1 converted to mol m-3
                km_tmp2 = 11.3d-5
                km_tmp3 = 2.52d-5
                rxn_ext = ( &
                    & v_tmp &
                    & *g2x/(g2x + km_tmp1 ) &
                    & *no3x/(no3x + km_tmp2 ) &
                    & *km_tmp3/(po2x*ko2 + km_tmp3 ) &
                    & *min(2d0*sat,1d0) &
                    & *exp(-0.5d0*((-log10(prox)-7d0)/1d0)**2d0) &! modified version using normal distribution with sigma = 1 
                    & )
                
                ! when using modified version using normal distribution with sigma = 1 
                dv_dph_tmp = exp(-0.5d0*((-log10(prox)-7d0)/1d0)**2d0) &
                    & *-0.5d0*2d0*((-log10(prox)-7d0)/1d0)  &
                    & *(-1d0) &
                    & *1d0/log(10d0)/prox
                    
                select case(trim(adjustl(sp_name)))
                    case('g2')
                        drxnext_dmsp = ( &
                            & v_tmp &
                            & * ( & 
                            & 1d0/(g2x + km_tmp1 ) &
                            & + g2x*(-1d0)/(g2x + km_tmp1 )**2d0 * 1d0 &
                            & ) &
                            & *no3x/(no3x + km_tmp2 ) &
                            & *km_tmp3/(po2x*ko2 + km_tmp3 ) &
                            & *min(2d0*sat,1d0) &
                            & *exp(-0.5d0*((-log10(prox)-7d0)/1d0)**2d0) &! modified version using normal distribution with sigma = 1 
                            & )
                    case('no3')
                        drxnext_dmsp = ( &
                            & v_tmp &
                            & *g2x/(g2x + km_tmp1 ) &
                            & * ( & 
                            & 1d0/(no3x + km_tmp2 ) &
                            & + no3x*(-1d0)/(no3x + km_tmp2 )**2d0 * 1d0 &
                            & ) &
                            & *km_tmp3/(po2x*ko2 + km_tmp3 ) &
                            & *min(2d0*sat,1d0) &
                            & *exp(-0.5d0*((-log10(prox)-7d0)/1d0)**2d0) &! modified version using normal distribution with sigma = 1 
                            & )
                    case('po2')
                        drxnext_dmsp = ( &
                            & v_tmp &
                            & *g2x/(g2x + km_tmp1 ) &
                            & *no3x/(no3x + km_tmp2 ) &
                            & *km_tmp3*(-1d0)/(po2x*ko2 + km_tmp3 )**2d0 * ko2 &
                            & *min(2d0*sat,1d0) &
                            & *exp(-0.5d0*((-log10(prox)-7d0)/1d0)**2d0) &! modified version using normal distribution with sigma = 1 
                            & )
                    case('pro')
                        drxnext_dmsp = ( &
                            & v_tmp &
                            & *g2x/(g2x + km_tmp1 ) &
                            & *no3x/(no3x + km_tmp2 ) &
                            & *km_tmp3/(po2x*ko2 + km_tmp3 ) &
                            & *min(2d0*sat,1d0) &
                            & *dv_dph_tmp &! modified version using normal distribution with sigma = 1 
                            & )
                    case default
                        drxnext_dmsp = 0d0
                endselect 
                
        endselect 
                
    case('g2n22') ! 2nd of 2 step denitrification (2 N2O  +  CH2O  ->  2 N2  +  CO2  +  H2O)  
        scheme = 'maggi08' ! Maggi et al. (2008) wihtout baterial, pH and water saturation functions
        
        select case(trim(adjustl(scheme)))
            case('maggi08')
                v_tmp = 1.23d-7*60d0*60d0*24d0*365d0
                km_tmp1 = 10d-5 * 1d6 ! mol L-1 converted to mol m-3
                km_tmp2 = 11.3d-5
                km_tmp3 = 2.52d-5
                rxn_ext = ( &
                    & v_tmp &
                    & *g2x/(g2x + km_tmp1 ) &
                    & *kn2o*pn2ox/(kn2o*pn2ox + km_tmp2 ) &
                    ! & *km_tmp3/(po2x*ko2 + km_tmp3 ) &
                    & *km_tmp3/(no3x + km_tmp3 ) &
                    & *min(2d0*sat,1d0) &
                    & *exp(-0.5d0*((-log10(prox)-7d0)/1d0)**2d0) &! modified version using normal distribution with sigma = 1 
                    & )
                
                ! when using modified version using normal distribution with sigma = 1 
                dv_dph_tmp = exp(-0.5d0*((-log10(prox)-7d0)/1d0)**2d0) &
                    & *-0.5d0*2d0*((-log10(prox)-7d0)/1d0)  &
                    & *(-1d0) &
                    & *1d0/log(10d0)/prox
                    
                select case(trim(adjustl(sp_name)))
                    case('g2')
                        drxnext_dmsp = ( &
                            & v_tmp &
                            & * ( & 
                            & 1d0/(g2x + km_tmp1 ) &
                            & + g2x*(-1d0)/(g2x + km_tmp1 )**2d0 * 1d0 &
                            & ) &
                            & *kn2o*pn2ox/(kn2o*pn2ox + km_tmp2 ) &
                            ! & *km_tmp3/(po2x*ko2 + km_tmp3 ) &
                            & *km_tmp3/(no3x + km_tmp3 ) &
                            & *min(2d0*sat,1d0) &
                            & *exp(-0.5d0*((-log10(prox)-7d0)/1d0)**2d0) &! modified version using normal distribution with sigma = 1 
                            & )
                    case('pn2o')
                        drxnext_dmsp = ( &
                            & v_tmp &
                            & *g2x/(g2x + km_tmp1 ) &
                            & * ( & 
                            & kn2o/(kn2o*pn2ox + km_tmp2 ) &
                            & + kn2o*pn2ox*(-1d0)/(kn2o*pn2ox + km_tmp2 )**2d0 * kn2o &
                            & ) &
                            ! & *km_tmp3/(po2x*ko2 + km_tmp3 ) &
                            & *km_tmp3/(no3x + km_tmp3 ) &
                            & *min(2d0*sat,1d0) &
                            & *exp(-0.5d0*((-log10(prox)-7d0)/1d0)**2d0) &! modified version using normal distribution with sigma = 1 
                            & )
                    ! case('po2')
                        ! drxnext_dmsp = ( &
                            ! & v_tmp &
                            ! & *g2x/(g2x + km_tmp1 ) &
                            ! & *kn2o*pn2ox/(kn2o*pn2ox + km_tmp2 ) &
                            ! & *km_tmp3*(-1d0)/(po2x*ko2 + km_tmp3 )**2d0 * ko2 &
                            ! & *min(2d0*sat,1d0) &
                            ! & *exp(-0.5d0*((-log10(prox)-7d0)/1d0)**2d0) &! modified version using normal distribution with sigma = 1 
                            ! & )
                    case('no3')
                        drxnext_dmsp = ( &
                            & v_tmp &
                            & *g2x/(g2x + km_tmp1 ) &
                            & *kn2o*pn2ox/(kn2o*pn2ox + km_tmp2 ) &
                            ! & *km_tmp3*(-1d0)/(po2x*ko2 + km_tmp3 )**2d0 * ko2 &
                            & *km_tmp3*(-1d0)/(no3x + km_tmp3 )**2d0 * 1d0 &
                            & *min(2d0*sat,1d0) &
                            & *exp(-0.5d0*((-log10(prox)-7d0)/1d0)**2d0) &! modified version using normal distribution with sigma = 1 
                            & )
                    case('pro')
                        drxnext_dmsp = ( &
                            & v_tmp &
                            & *g2x/(g2x + km_tmp1 ) &
                            & *kn2o*pn2ox/(kn2o*pn2ox + km_tmp2 ) &
                            ! & *km_tmp3/(po2x*ko2 + km_tmp3 ) &
                            & *km_tmp3/(no3x + km_tmp3 ) &
                            & *min(2d0*sat,1d0) &
                            & *dv_dph_tmp &! modified version using normal distribution with sigma = 1 
                            & )
                    case default
                        drxnext_dmsp = 0d0
                endselect 
                
        endselect 
        
        
    case default 
        rxn_ext = 0d0
        drxnext_dmsp = 0d0
        
endselect

rxnext_error = .false.
if (any(isnan(rxn_ext)) .or. any(isnan(drxnext_dmsp))) then 
    print *,'nan in calc_rxn_ext_dev_2'
    rxnext_error = .true.
    ! stop
endif 

endsubroutine calc_rxn_ext_dev_2

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine make_transmx(  &
    & labs,nsp_sld,turbo2,nobio,dz,poro,nz,z,zml_ref,dbl_ref,fick,till,tol,save_trans  &! input
    & ,trans,nonlocal,izml  &! output 
    & )
implicit none
integer,intent(in)::nsp_sld,nz
real(kind=8),intent(in)::dz(nz),poro(nz),z(nz),zml_ref,dbl_ref,tol
real(kind=8)::sporo(nz)
logical,intent(in)::labs(nsp_sld),turbo2(nsp_sld),nobio(nsp_sld),fick(nsp_sld),till(nsp_sld),save_trans
real(kind=8),intent(out)::trans(nz,nz,nsp_sld)
logical,intent(out)::nonlocal(nsp_sld)
integer,intent(out)::izml
integer iz,isp,iiz,izdbl
real(kind=8) :: translabs(nz,nz),dbio(nz),transdbio(nz,nz),transturbo2(nz,nz),transtill(nz,nz)
real(kind=8) :: zml(nsp_sld),probh,dbl
character(10) chr

sporo = 1d0 - poro
trans = 0d0
!~~~~~~~~~~~~ loading transition matrix from LABS ~~~~~~~~~~~~~~~~~~~~~~~~
if (any(labs)) then
    translabs = 0d0

    open(unit=88,file='../input/labs-mtx.txt',action='read',status='unknown')
    do iz=1,nz
        read(88,*) translabs(iz,:)  ! writing 
    enddo
    close(88)

endif

if (.true.) then  ! devided by the time duration when transition matrices are created in LABS and weakening by a factor
! if (.false.) then 
    ! translabs = translabs *365.25d0/10d0*1d0/3d0  
    ! translabs = translabs *365.25d0/10d0*1d0/15d0  
    translabs = translabs *365.25d0/10d0*1d0/10d0
endif
!~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
zml=zml_ref ! mixed layer depth assumed to be a reference value at first 

dbl = dbl_ref

nonlocal = .false. ! initial assumption 
do isp=1,nsp_sld
    if (turbo2(isp) .or. labs(isp)) nonlocal(isp)=.true. ! if mixing is made by turbo2 or labs, then nonlocal 
    
    dbio=0d0
    izdbl=0
    do iz = 1, nz
        if (z(iz) <= dbl) then 
            dbio(iz) = 0d0
            izdbl = iz
        elseif (dbl < z(iz) .and. z(iz) <=zml(isp)) then
            ! dbio(iz) =  0.15d-4   !  within mixed layer 150 cm2/kyr (Emerson, 1985) 
            dbio(iz) =  2d-4   !  within mixed layer ~5-6e-7 m2/day (Astete et al., 2016) 
            ! dbio(iz) =  2d-4*exp(z(iz)/0.1d0)   !  within mixed layer ~5-6e-7 m2/day (Astete et al., 2016) 
            ! dbio(iz) =  2d-7*exp(z(iz)/1d0)   !  within mixed layer ~5-6e-7 m2/day (Astete et al., 2016) 
            ! dbio(iz) =  2d-10   !  just a small value 
            ! dbio(iz) =  2d-3   !  just a value changed 
            izml = iz   ! determine grid of bottom of mixed layer 
        else
            dbio(iz) =  0d0 ! no biodiffusion in deeper depths 
        endif
    enddo

    transdbio = 0d0   ! transition matrix to realize Fickian mixing with biodiffusion coefficient dbio which is defined just above 
    do iz = max(1,izdbl), izml
        if (iz==max(1,izdbl)) then 
            transdbio(iz,iz) = 0.5d0*(sporo(iz)*dbio(iz)+sporo(iz+1)*dbio(iz+1))*(-1d0)/(0.5d0*(dz(iz)+dz(iz+1)))
            transdbio(iz+1,iz) = 0.5d0*(sporo(iz)*dbio(iz)+sporo(iz+1)*dbio(iz+1))*(1d0)/(0.5d0*(dz(iz)+dz(iz+1)))
        elseif (iz==izml) then 
            transdbio(iz,iz) = 0.5d0*(sporo(Iz)*dbio(iz)+sporo(Iz-1)*dbio(iz-1))*(-1d0)/(0.5d0*(dz(iz)+dz(iz-1)))
            transdbio(iz-1,iz) = 0.5d0*(sporo(iz)*dbio(iz)+sporo(iz-1)*dbio(iz-1))*(1d0)/(0.5d0*(dz(iz)+dz(iz-1)))
        else 
            transdbio(iz,iz) = 0.5d0*(sporo(iz)*dbio(iz)+sporo(iz-1)*dbio(iz-1))*(-1d0)/(0.5d0*(dz(iz)+dz(iz-1)))  &
                + 0.5d0*(sporo(iz)*dbio(iz)+sporo(iz+1)*dbio(iz+1))*(-1d0)/(0.5d0*(dz(iz)+dz(iz+1)))
            transdbio(iz-1,iz) = 0.5d0*(sporo(iz)*dbio(iz)+sporo(iz-1)*dbio(iz-1))*(1d0)/(0.5d0*(dz(iz)+dz(iz-1)))
            transdbio(iz+1,iz) = 0.5d0*(sporo(iz)*dbio(iz)+sporo(iz+1)*dbio(iz+1))*(1d0)/(0.5d0*(dz(iz)+dz(iz+1)))
        endif
    enddo
    ! do iz = max(1,izdbl), izml
        ! if (iz==max(1,izdbl)) then 
            ! transdbio(iz,iz) = 0.5d0*(dbio(iz)+dbio(iz+1))*(-1d0)/(0.5d0*(dz(iz)+dz(iz+1)))
            ! transdbio(iz+1,iz) = 0.5d0*(dbio(iz)+dbio(iz+1))*(1d0)/(0.5d0*(dz(iz)+dz(iz+1)))
        ! elseif (iz==izml) then 
            ! transdbio(iz,iz) = 0.5d0*(dbio(iz)+dbio(iz-1))*(-1d0)/(0.5d0*(dz(iz)+dz(iz-1)))
            ! transdbio(iz-1,iz) = 0.5d0*(dbio(iz)+dbio(iz-1))*(1d0)/(0.5d0*(dz(iz)+dz(iz-1)))
        ! else 
            ! transdbio(iz,iz) = 0.5d0*(dbio(iz)+dbio(iz-1))*(-1d0)/(0.5d0*(dz(iz)+dz(iz-1)))  &
                ! + 0.5d0*(dbio(iz)+dbio(iz+1))*(-1d0)/(0.5d0*(dz(iz)+dz(iz+1)))
            ! transdbio(iz-1,iz) = 0.5d0*(dbio(iz)+dbio(iz-1))*(1d0)/(0.5d0*(dz(iz)+dz(iz-1)))
            ! transdbio(iz+1,iz) = 0.5d0*(dbio(iz)+dbio(iz+1))*(1d0)/(0.5d0*(dz(iz)+dz(iz+1)))
        ! endif
    ! enddo
    
    ! Added; changes have been made here rather than in solving governing eqs.
    do iz=1,nz
        transdbio(:,iz) = transdbio(:,iz)/dz(iz)
    enddo 

    !~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ 
    ! transition matrix for random mixing 
    transturbo2 = 0d0
    ! ending up in upward mixing 
    probh = 0.0010d0
    transturbo2(max(1,izdbl):izml,max(1,izdbl):izml) = probh  ! arbitrary assumed probability 
    do iz=1,izml  ! when i = j, transition matrix contains probabilities with which particles are moved from other layers of sediment   
       transturbo2(iz,iz)=-probh*(izml-max(1,izdbl))  
    enddo
    ! trying real homogeneous 
    transturbo2 = 0d0
    probh = 0.001d0
    do iz=1,izml 
        do iiz=1,izml
            if (iiz/=iz) then 
                transturbo2(iiz,iz) = probh!*dz(iz)/dz(iiz)
                transturbo2(iiz,iiz) = transturbo2(iiz,iiz) - transturbo2(iiz,iz)
            endif 
        enddo
    enddo
    
    ! trying inverse mixing 
    transtill = 0d0
    probh = 0.010d0
    probh = 0.10d0
    do iz=1,izml  ! when i = j, transition matrix contains probabilities with which particles are moved from other layers of sediment   
        ! transtill(iz,iz)=-probh*dz(iz)/dz(izml+1-iz) !*(iz - izml*0.5d0)**2d0/(izml**2d0*0.25d0)
        ! transtill(izml+1-iz,iz)=probh*dz(iz)/dz(izml+1-iz) ! *(iz - izml*0.5d0)**2d0/(izml**2d0*0.25d0)
        ! do iiz = izml+1-iz,iz+1,-1
            ! transtill(iiz,iz)= probh*dz(iz)/dz(iiz)*(iiz/real(izml+1-iz,kind=8))
        ! enddo 
        ! transtill(iz,iz) = -sum(transtill(:,iz))
        do iiz=1,izml
            if (iiz/=iz) then 
                if (iiz==iz-1 .or. iiz == iz+1 .or. iiz == izml + 1 - iz ) then 
                    transtill(iiz,iz)= probh !*dz(iz)/dz(iiz) 
                    ! transtill(iiz,iiz) = transtill(iiz,iiz) - transtill(iiz,iz)
                endif 
            endif 
        enddo 
        transtill(iz,iz) = -sum(transtill(:,iz))
    enddo
    

    ! if (turbo2(isp)) translabs = transturbo2   ! translabs temporarily used to represents nonlocal mixing 
    
    ! added 
    do iz =1,nz
        do iiz= 1,nz
            translabs(iiz,iz) = translabs(iiz,iz)/dz(iz)*dz(iiz)
            transturbo2(iiz,iz) = transturbo2(iiz,iz)/dz(iz)*dz(iiz)
            transtill(iiz,iz) = transtill(iiz,iz)/dz(iz)*dz(iiz)
        enddo 
    enddo 
    
    trans(:,:,isp) = 0d0 
    
    if (nobio(isp)) cycle
    
    if (fick(isp)) then 
        trans(:,:,isp) = trans(:,:,isp) + transdbio(:,:)
    endif 
    
    if (turbo2(isp)) then 
        trans(:,:,isp) = trans(:,:,isp) + transturbo2(:,:)
    endif 
    
    if (labs(isp)) then 
        trans(:,:,isp) = trans(:,:,isp) + translabs(:,:)
    endif 
    
    if (till(isp)) then 
        trans(:,:,isp) = trans(:,:,isp) + transtill(:,:)
    endif 
    
    ! if (any(abs(sum(trans(:,:,isp),dim=1))>tol)) then 
        ! print *, 'transition matrix can be non-conservative'
        ! write(chr,'(i3.3)') isp
        ! open(unit=88,file='./mtx-'//trim(adjustl(chr))//'.txt',action='write',status='replace')
        ! do iz=1,nz
            ! write(88,*) (trans(iz,iiz,isp),iiz=1,nz)  ! writing 
        ! enddo
        ! close(88)
        ! stop
    ! endif 
    
    if (save_trans) then 
        write(chr,'(i3.3)') isp
        open(unit=88,file='./mtx-'//trim(adjustl(chr))//'.txt',action='write',status='replace')
        do iz=1,nz
            write(88,*) (trans(iz,iiz,isp),iiz=1,nz)  ! writing 
        enddo
        close(88)
    endif 
    
    ! trans(:,:,isp) = transdbio(:,:)  !  firstly assume local mixing implemented by dbio 

    ! if (nonlocal(isp)) trans(:,:,isp) = translabs(:,:)  ! if nonlocal, replaced by either turbo2 mixing or labs mixing 
    ! if (nobio(isp)) trans(:,:,isp) = 0d0  ! if assuming no bioturbation, transition matrix is set at zero  
enddo
! even when all are local Fickian mixing, mixing treatment must be the same as in case of nonlocal 
! if mixing intensity and depths are different between different species  
if (all(.not.nonlocal)) then  
    do isp=1,nsp_sld-1
        if (any(trans(:,:,isp+1)/=trans(:,:,isp))) nonlocal=.true.
    enddo
endif 

endsubroutine make_transmx

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine alsilicate_aq_gas_1D_v3_1( &
    ! new input 
    & nz,nsp_sld,nsp_sld_2,nsp_aq,nsp_aq_ph,nsp_gas_ph,nsp_gas,nsp3,nrxn_ext &
    & ,chrsld,chrsld_2,chraq,chraq_ph,chrgas_ph,chrgas,chrrxn_ext  &
    & ,msldi,msldth,mv,maqi,maqth,daq,mgasi,mgasth,dgasa,dgasg,khgasi &
    & ,staq,stgas,msld,ksld,msldsupp,maq,maqsupp,mgas,mgassupp &
    & ,stgas_ext,stgas_dext,staq_ext,stsld_ext,staq_dext,stsld_dext &
    & ,nsp_aq_all,nsp_gas_all,nsp_sld_all,nsp_aq_cnst,nsp_gas_cnst &
    & ,chraq_cnst,chraq_all,chrgas_cnst,chrgas_all,chrsld_all &
    & ,maqc,mgasc,keqgas_h,keqaq_h,keqaq_c,keqsld_all,keqaq_s,keqaq_no3,keqaq_nh3 &
    & ,nrxn_ext_all,chrrxn_ext_all,mgasth_all,maqth_all,krxn1_ext_all,krxn2_ext_all &
    & ,nsp_sld_cnst,chrsld_cnst,msldc,rho_grain,msldth_all,mv_all,staq_all,stgas_all &
    & ,turbo2,labs,trans,method_precalc,display,chrflx,sld_enforce &! input
    & ,nsld_kinspc,chrsld_kinspc,kin_sld_spc &! input
    !  old inputs
    & ,hr,poro,z,dz,w_btm,sat,pro,poroprev,tora,v,tol,it,nflx,kw,so4fprev & 
    & ,ucv,torg,cplprec,rg,tc,sec2yr,tempk_0,proi,poroi,up,dwn,cnr,adf,msldunit  &
    ! old inout
    & ,dt,flgback,w &    
    ! output 
    & ,msldx,omega,flx_sld,maqx,flx_aq,mgasx,flx_gas,rxnext,prox,nonprec,rxnsld,flx_co2sp,so4f & 
    & )
    
implicit none 

integer,intent(in)::nz,nflx
real(kind=8),intent(in)::w_btm,tol,kw,ucv,rho_grain,rg,tc,sec2yr,tempk_0,proi,poroi
real(kind=8),dimension(nz),intent(in)::hr,poro,z,sat,tora,v,poroprev,dz,torg,pro,up,dwn,cnr,adf,so4fprev
real(kind=8),dimension(nz),intent(out)::prox,so4f
real(kind=8),dimension(nz),intent(inout)::w
integer,intent(inout)::it
integer iter
logical,intent(in)::cplprec,method_precalc,display
logical,intent(inout)::flgback
character(3),intent(in)::msldunit
real(kind=8),intent(in)::dt
real(kind=8) error

integer,intent(in)::nsp_sld,nsp_sld_2,nsp_aq,nsp_aq_ph,nsp_gas_ph,nsp_gas,nsp3,nrxn_ext,nsld_kinspc
character(5),dimension(nsp_sld),intent(in)::chrsld
character(5),dimension(nsp_sld_2),intent(in)::chrsld_2
character(5),dimension(nsp_aq),intent(in)::chraq
character(5),dimension(nsp_aq_ph),intent(in)::chraq_ph
character(5),dimension(nsp_gas_ph),intent(in)::chrgas_ph
character(5),dimension(nsp_gas),intent(in)::chrgas
character(5),dimension(nrxn_ext),intent(in)::chrrxn_ext
character(5),dimension(nsld_kinspc),intent(in)::chrsld_kinspc
real(kind=8),dimension(nsp_sld),intent(in)::msldi,msldth,mv
real(kind=8),dimension(nsp_aq),intent(in)::maqi,maqth,daq 
real(kind=8),dimension(nsp_gas),intent(in)::mgasi,mgasth,dgasa,dgasg,khgasi
real(kind=8),dimension(nsp_gas)::dgasi
real(kind=8),dimension(nsp_sld,nsp_aq),intent(in)::staq
real(kind=8),dimension(nsp_sld,nsp_gas),intent(in)::stgas
real(kind=8),dimension(nsp_sld,nz),intent(in)::msld,msldsupp 
real(kind=8),dimension(nsp_sld,nz),intent(inout)::ksld
real(kind=8),dimension(nz,nz,nsp_sld),intent(in)::trans
real(kind=8),dimension(nsp_sld,nz),intent(inout)::msldx,omega,nonprec,rxnsld
real(kind=8),dimension(nsp_sld,nz)::domega_dpro,dmsld,dksld_dpro,drxnsld_dmsld,dksld_dso4f,domega_dso4f
real(kind=8),dimension(nsp_sld,nsp_aq,nz)::domega_dmaq,dksld_dmaq,drxnsld_dmaq
real(kind=8),dimension(nsp_sld,nsp_gas,nz)::domega_dmgas,dksld_dmgas,drxnsld_dmgas
real(kind=8),dimension(nsp_sld,nflx,nz),intent(out)::flx_sld
real(kind=8),dimension(nsp_aq,nz),intent(in)::maq,maqsupp
real(kind=8),dimension(nsp_aq,nz),intent(inout)::maqx 
real(kind=8),dimension(nsp_aq,nz)::dprodmaq,dmaq,dso4fdmaq 
real(kind=8),dimension(nsp_aq,nflx,nz),intent(out)::flx_aq
real(kind=8),dimension(nsp_gas,nz),intent(in)::mgas,mgassupp
real(kind=8),dimension(nsp_gas,nz),intent(inout)::mgasx 
real(kind=8),dimension(nsp_gas,nz)::khgasx,khgas,dgas,agasx,agas,rxngas,dkhgas_dpro,dprodmgas,dmgas,dso4fdmgas,dkhgas_dso4f
real(kind=8),dimension(nsp_gas,nsp_aq,nz)::dkhgas_dmaq,ddgas_dmaq,dagas_dmaq,drxngas_dmaq 
real(kind=8),dimension(nsp_gas,nsp_sld,nz)::drxngas_dmsld 
real(kind=8),dimension(nsp_gas,nsp_gas,nz)::dkhgas_dmgas,ddgas_dmgas,dagas_dmgas,drxngas_dmgas 
real(kind=8),dimension(nsp_gas,nflx,nz),intent(out)::flx_gas 
real(kind=8),dimension(nrxn_ext,nz),intent(inout)::rxnext
real(kind=8),dimension(nrxn_ext,nz)::drxnext_dpro,drxnext_dso4f
real(kind=8),dimension(nrxn_ext,nsp_gas),intent(in)::stgas_ext,stgas_dext
real(kind=8),dimension(nrxn_ext,nsp_aq),intent(in)::staq_ext,staq_dext
real(kind=8),dimension(nrxn_ext,nsp_sld),intent(in)::stsld_ext,stsld_dext
real(kind=8),dimension(nrxn_ext,nsp_gas,nz)::drxnext_dmgas
real(kind=8),dimension(nrxn_ext,nsp_aq,nz)::drxnext_dmaq
real(kind=8),dimension(nrxn_ext,nsp_sld,nz)::drxnext_dmsld
real(kind=8),dimension(nsld_kinspc)::kin_sld_spc
logical,dimension(nsp_sld),intent(in)::labs,turbo2

integer,intent(in)::nsp_aq_all,nsp_gas_all,nsp_sld_all,nsp_aq_cnst,nsp_gas_cnst,nsp_sld_cnst
character(5),dimension(nsp_aq_cnst),intent(in)::chraq_cnst
character(5),dimension(nsp_aq_all),intent(in)::chraq_all
character(5),dimension(nsp_gas_cnst),intent(in)::chrgas_cnst
character(5),dimension(nsp_gas_all),intent(in)::chrgas_all
character(5),dimension(nsp_sld_cnst),intent(in)::chrsld_cnst
character(5),dimension(nsp_sld_all),intent(in)::chrsld_all
real(kind=8),dimension(nsp_aq_cnst,nz),intent(in)::maqc
real(kind=8),dimension(nsp_gas_cnst,nz),intent(in)::mgasc
real(kind=8),dimension(nsp_sld_cnst,nz),intent(in)::msldc
real(kind=8),dimension(nsp_sld_all,nsp_aq_all),intent(in)::staq_all
real(kind=8),dimension(nsp_sld_all,nsp_gas_all),intent(in)::stgas_all
real(kind=8),dimension(nsp_gas_all,3),intent(in)::keqgas_h
real(kind=8),dimension(nsp_aq_all,4),intent(in)::keqaq_h
real(kind=8),dimension(nsp_aq_all,2),intent(in)::keqaq_c
real(kind=8),dimension(nsp_aq_all,2),intent(in)::keqaq_s
real(kind=8),dimension(nsp_aq_all,2),intent(in)::keqaq_no3
real(kind=8),dimension(nsp_aq_all,2),intent(in)::keqaq_nh3
real(kind=8),dimension(nsp_sld_all),intent(in)::keqsld_all,msldth_all,mv_all

real(kind=8),dimension(nsp_aq_all,nz)::dprodmaq_all,dso4fdmaq_all
real(kind=8),dimension(nsp_gas_all,nz)::dprodmgas_all,dso4fdmgas_all

real(kind=8),dimension(nz)::domega_dpro_loc,domega_dso4f_loc
real(kind=8),dimension(nsp_gas_all,nz)::domega_dmgas_all
real(kind=8),dimension(nsp_aq_all,nz)::domega_dmaq_all

real(kind=8),dimension(nsp_gas_all,nz)::mgasx_loc
real(kind=8),dimension(nsp_gas_all,nz)::khgas_all,khgasx_all,dkhgas_dpro_all,dkhgas_dso4f_all
real(kind=8),dimension(nsp_gas_all,nsp_aq_all,nz)::dkhgas_dmaq_all
real(kind=8),dimension(nsp_gas_all,nsp_gas_all,nz)::dkhgas_dmgas_all

character(5),dimension(nflx),intent(in)::chrflx

integer ieqgas_h0,ieqgas_h1,ieqgas_h2
data ieqgas_h0,ieqgas_h1,ieqgas_h2/1,2,3/

integer ieqaq_h1,ieqaq_h2,ieqaq_h3,ieqaq_h4
data ieqaq_h1,ieqaq_h2,ieqaq_h3,ieqaq_h4/1,2,3,4/

integer ieqaq_co3,ieqaq_hco3
data ieqaq_co3,ieqaq_hco3/1,2/

integer ieqaq_so4,ieqaq_so42
data ieqaq_so4,ieqaq_so42/1,2/

integer,intent(in)::nrxn_ext_all

character(5),dimension(nrxn_ext_all),intent(in)::chrrxn_ext_all

real(kind=8),dimension(nsp_gas_all),intent(in)::mgasth_all
real(kind=8),dimension(nsp_aq_all),intent(in)::maqth_all
real(kind=8),dimension(nrxn_ext_all,nz),intent(in)::krxn1_ext_all,krxn2_ext_all

real(kind=8),dimension(4,nflx,nz),intent(out)::flx_co2sp

integer iz,row,ie,ie2,iflx,isps,ispa,ispg,ispa2,ispg2,col,irxn,isps2,iiz,isps_kinspc,row_w,col_w
integer::itflx,iadv,idif,irain,ires
integer::ph_iter,ph_iter2
data itflx,iadv,idif,irain/1,2,3,4/

integer,dimension(nsp_sld)::irxn_sld 
integer,dimension(nrxn_ext)::irxn_ext 

real(kind=8) d_tmp,caq_tmp,caq_tmp_p,caq_tmp_n,caqth_tmp,caqi_tmp,rxn_tmp,caq_tmp_prev,drxndisp_tmp &
    & ,k_tmp,mv_tmp,omega_tmp,m_tmp,mth_tmp,mi_tmp,mp_tmp,msupp_tmp,mprev_tmp,omega_tmp_th,rxn_ext_tmp &
    & ,edif_tmp,edif_tmp_n,edif_tmp_p,khco2n_tmp,pco2n_tmp,edifn_tmp,caqsupp_tmp,kco2,k1,k2,kho,sw_red &
    & ,flx_max,flx_max_max,proi_tmp,knh3,k1nh3,kn2o,wp_tmp,w_tmp,sporo_tmp,sporop_tmp,sporoprev_tmp  &
    & ,mn_tmp,wn_tmp,sporon_tmp

real(kind=8),parameter::infinity = huge(0d0)
real(kind=8),parameter::fact = 1d-3
real(kind=8),parameter::dconc = 1d-14
real(kind=8),parameter::maxfact = 1d200
! real(kind=8),parameter::threshold = log(maxfact)
real(kind=8),parameter::threshold = 10d0
! real(kind=8),parameter::threshold = 3d0
! real(kind=8),parameter::corr = 1.5d0
real(kind=8),parameter::corr = exp(threshold)

real(kind=8),dimension(nz)::dummy,dummy2,dummy3,kin,dkin_dmsp,dumtest,sporo

logical print_cb,ph_error,omega_error,rxnext_error
character(500) print_loc
character(20) chrfmt

integer,parameter :: iter_max = 50
! integer,parameter :: iter_max = 300

integer :: nz_disp = 10

real(kind=8) amx3(nsp3*nz,nsp3*nz),ymx3(nsp3*nz),emx3(nsp3*nz)
integer ipiv3(nsp3*nz)
integer info 

external DGESV

logical::chkflx = .true.
logical::dt_norm = .true.
logical::kin_iter = .true.
logical::new_gassol = .true.
! logical::new_gassol = .false.

! logical::sld_enforce = .false.
logical,intent(in)::sld_enforce != .true.

character(10),dimension(nsp_sld):: precstyle 
real(kind=8) msld_seed ,fact2
real(kind=8):: fact_tol = 1d-3
real(kind=8):: dt_th = 1d-6
real(kind=8):: flx_tol = 1d-4 != tol*fact_tol*(z(nz)+0.5d0*dz(nz))
! real(kind=8):: flx_tol = 1d-3 ! desparate to make things converge 
! real(kind=8):: flx_max_tol = 1d-9 != tol*fact_tol*(z(nz)+0.5d0*dz(nz)) ! working for most cases but not when spinup with N cycles
real(kind=8):: flx_max_tol = 1d-6 != tol*fact_tol*(z(nz)+0.5d0*dz(nz)) 
integer solve_sld 

!-----------------------------------------------


precstyle = 'def'
! precstyle = 'full'
! precstyle = 'full_lim'
! precstyle = 'seed '
! precstyle = '2/3'

do isps = 1, nsp_sld
    select case(trim(adjustl(chrsld(isps))))
        case('g1','g2','g3')
            precstyle(isps) = 'decay'
        case default 
            precstyle(isps) = 'def'
            ! precstyle(isps) = '2/3'
            ! precstyle(isps) = '2/3noporo'
    endselect
enddo 

msld_seed = 1d-20

! flx_tol = tol*fact_tol*(z(nz)+0.5d0*dz(nz))
! flx_tol = 1d-4

if (sld_enforce) then 
    solve_sld = 0
else
    solve_sld = 1
endif 

sw_red = 1d0
if (.not.method_precalc) sw_red = -1d100
sw_red = -1d100

do isps=1,nsp_sld
    irxn_sld(isps) = 4+isps
enddo 

do irxn=1,nrxn_ext
    irxn_ext(irxn) = 4+nsp_sld+irxn
enddo 

ires = nflx

print_cb = .false. 
print_loc = './ph.txt'

kco2 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h0)
k1 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h1)
k2 = keqgas_h(findloc(chrgas_all,'pco2',dim=1),ieqgas_h2)

kho = keqgas_h(findloc(chrgas_all,'po2',dim=1),ieqgas_h0)

knh3 = keqgas_h(findloc(chrgas_all,'pnh3',dim=1),ieqgas_h0)
k1nh3 = keqgas_h(findloc(chrgas_all,'pnh3',dim=1),ieqgas_h1)

kn2o = keqgas_h(findloc(chrgas_all,'pn2o',dim=1),ieqgas_h0)

sporo = 1d0 - poro
if (msldunit=='blk') sporo = 1d0

! so4fprev = so4f

! w = win
    
nonprec = 1d0 ! primary minerals only dissolve
if (cplprec)then
    do isps = 1, nsp_sld
        if (any(chrsld_2 == chrsld(isps))) then  
            nonprec(isps,:) = 0d0 ! allowing precipitation for secondary phases
        endif 
    enddo
endif 

! print *, staq
! print *, mgx
! print *, six
! print *, mfosupp
! stop

if (any(isnan(tora)))then 
    print*,tora
endif 

dummy = 0d0
dummy2 = 0d0

error = 1d4
iter = 0

! print *, 'starting silciate calculation'

do while ((.not.isnan(error)).and.(error > tol*fact_tol))

    amx3=0.0d0
    ymx3=0.0d0 
    emx3=0.0d0 
    
    flx_sld = 0d0
    flx_aq = 0d0
    flx_gas = 0d0
    
    ! pH calculation and its derivative wrt aq and gas species
    
    
    call calc_pH_v7_3( &
        & nz,kw,nsp_aq,nsp_gas,nsp_aq_all,nsp_gas_all,nsp_aq_cnst,nsp_gas_cnst &! input 
        & ,chraq,chraq_cnst,chraq_all,chrgas,chrgas_cnst,chrgas_all &!input
        & ,maqx,maqc,mgasx,mgasc,keqgas_h,keqaq_h,keqaq_c,keqaq_s,maqth_all,keqaq_no3,keqaq_nh3 &! input
        & ,print_cb,print_loc,z &! input 
        & ,dprodmaq_all,dprodmgas_all,dso4fdmaq_all,dso4fdmgas_all &! output
        & ,prox,ph_error,so4f,ph_iter &! output
        & ) 

    if (ph_error) then 
        flgback = .true.
        return
    endif 
    
    dprodmaq = 0d0
    dso4fdmaq = 0d0
    do ispa=1,nsp_aq
        if (any (chraq_ph == chraq(ispa))) then 
            dprodmaq(ispa,:)=dprodmaq_all(findloc(chraq_all,chraq(ispa),dim=1),:)
            dso4fdmaq(ispa,:)=dso4fdmaq_all(findloc(chraq_all,chraq(ispa),dim=1),:)
        endif 
    enddo 
    
    dprodmgas = 0d0
    dso4fdmgas = 0d0
    do ispg=1,nsp_gas
        if (any (chrgas_ph == chrgas(ispg))) then 
            dprodmgas(ispg,:)=dprodmgas_all(findloc(chrgas_all,chrgas(ispg),dim=1),:)
            dso4fdmGas(ispg,:)=dso4fdmgas_all(findloc(chrgas_all,chrgas(ispg),dim=1),:)
        endif 
    enddo 
    
    ! recalculation of rate constants for mineral reactions
    if (kin_iter) then 
        ksld = 0d0
        dksld_dpro = 0d0
        dksld_dso4f = 0d0
        dksld_dmaq = 0d0
        dksld_dmgas = 0d0
        
        call get_mgasx_all( &
            & nz,nsp_gas_all,nsp_gas,nsp_gas_cnst &
            & ,chrgas,chrgas_all,chrgas_cnst &
            & ,mgasx,mgasc &
            & ,mgasx_loc  &! output
            & )
        
        do isps =1,nsp_sld 
            call sld_kin( &
                & nz,rg,tc,sec2yr,tempk_0,prox,poro,hr,kw,kho,mv(isps) &! input
                & ,nsp_gas_all,chrgas_all,mgasx_loc &! input
                & ,chrsld(isps),'pro  ' &! input 
                & ,kin,dkin_dmsp &! output
                & ) 
            ksld(isps,:) = kin
            dksld_dpro(isps,:) = dkin_dmsp
            
            do ispa = 1,nsp_aq
                if (any (chraq_ph == chraq(ispa)) .or. staq(isps,ispa)/=0d0 ) then 
                    call sld_kin( &
                        & nz,rg,tc,sec2yr,tempk_0,prox,poro,hr,kw,kho,mv(isps) &! input
                        & ,nsp_gas_all,chrgas_all,mgasx_loc &! input
                        & ,chrsld(isps),chraq(ispa) &! input 
                        & ,kin,dkin_dmsp &! output
                        & ) 
                    dksld_dmaq(isps,ispa,:) = dkin_dmsp + ( &
                        & dksld_dpro(isps,:)*dprodmaq(ispa,:) &
                        & +dksld_dso4f(isps,:)*dso4fdmaq(ispa,:) &
                        & )
                endif 
            enddo 
            
            do ispg = 1,nsp_gas
                if (any (chrgas_ph == chrgas(ispg)) .or. stgas(isps,ispg)/=0d0) then 
                    call sld_kin( &
                        & nz,rg,tc,sec2yr,tempk_0,prox,poro,hr,kw,kho,mv(isps) &! input
                        & ,nsp_gas_all,chrgas_all,mgasx_loc &! input
                        & ,chrsld(isps),chrgas(ispg) &! input 
                        & ,kin,dkin_dmsp &! output
                        & ) 
                    dksld_dmgas(isps,ispg,:) = dkin_dmsp + ( &
                        & dksld_dpro(isps,:)*dprodmgas(ispg,:) &
                        & +dksld_dso4f(isps,:)*dso4fdmgas(ispg,:) &
                        & )
                endif 
            enddo 
        
        enddo 
    else 
        dksld_dpro = 0d0
        dksld_dso4f = 0d0
        dksld_dmaq = 0d0
        dksld_dmgas = 0d0
    endif 
    
    ! if kin const. is specified in input file 
    if (nsld_kinspc > 0) then 
        do isps_kinspc=1,nsld_kinspc    
            if ( any( chrsld == chrsld_kinspc(isps_kinspc))) then 
                select case (trim(adjustl(chrsld_kinspc(isps_kinspc))))
                    case('g1','g2','g3') ! for OMs, turn over year needs to be provided [yr]
                        ksld(findloc(chrsld,chrsld_kinspc(isps_kinspc),dim=1),:) = ( &                   
                            & 1d0/kin_sld_spc(isps_kinspc) &
                            & ) 
                        dksld_dpro(findloc(chrsld,chrsld_kinspc(isps_kinspc),dim=1),:) = 0d0
                        dksld_dso4f(findloc(chrsld,chrsld_kinspc(isps_kinspc),dim=1),:) = 0d0
                        dksld_dmaq(findloc(chrsld,chrsld_kinspc(isps_kinspc),dim=1),:,:) = 0d0
                        dksld_dmgas(findloc(chrsld,chrsld_kinspc(isps_kinspc),dim=1),:,:) = 0d0
                    case default ! otherwise, usual rate constant [mol/m2/yr]
                        ksld(findloc(chrsld,chrsld_kinspc(isps_kinspc),dim=1),:) = ( &                            
                            & kin_sld_spc(isps_kinspc) &
                            & ) 
                        dksld_dpro(findloc(chrsld,chrsld_kinspc(isps_kinspc),dim=1),:) = 0d0
                        dksld_dso4f(findloc(chrsld,chrsld_kinspc(isps_kinspc),dim=1),:) = 0d0
                        dksld_dmaq(findloc(chrsld,chrsld_kinspc(isps_kinspc),dim=1),:,:) = 0d0
                        dksld_dmgas(findloc(chrsld,chrsld_kinspc(isps_kinspc),dim=1),:,:) = 0d0
                end select 
            endif 
        enddo 
    endif 
                    
    
    ! saturation state calc. and their derivatives wrt aq and gas species
    
    ! print *,'ksld',ksld(findloc(chrsld,'gt',dim=1),:)
    
    omega = 0d0
    domega_dpro = 0d0
    domega_dso4f = 0d0
    domega_dmaq = 0d0
    domega_dmgas = 0d0
    
    do isps =1, nsp_sld
    
        ! dummy = 0d0
        ! dummy2 = 0d0
        ! call calc_omega_dev_v2( &
            ! & nz,nsp_aq,nsp_gas,nsp_aq_all,nsp_sld_all,nsp_gas_all,nsp_aq_cnst,nsp_gas_cnst &! input 
            ! & ,chraq,chraq_cnst,chraq_all,chrsld_all,chrgas,chrgas_cnst,chrgas_all &!input
            ! & ,maqx,maqc,mgasx,mgasc,keqgas_h,keqaq_h,keqaq_c,keqsld_all,mgasth_all,keqaq_s,so4f,staq_all &! input
            ! & ,prox,chrsld(isps),'pro  ' &! input 
            ! & ,dummy,dummy2,omega_error &! output
            ! & )
        ! if (omega_error) then
            ! flgback = .true.
            ! return 
        ! endif 
        ! omega(isps,:) = dummy
        ! domega_dpro(isps,:) = dummy2
    
        ! dummy = 0d0
        ! dummy2 = 0d0
        ! call calc_omega_dev_v2( &
            ! & nz,nsp_aq,nsp_gas,nsp_aq_all,nsp_sld_all,nsp_gas_all,nsp_aq_cnst,nsp_gas_cnst &! input 
            ! & ,chraq,chraq_cnst,chraq_all,chrsld_all,chrgas,chrgas_cnst,chrgas_all &!input
            ! & ,maqx,maqc,mgasx,mgasc,keqgas_h,keqaq_h,keqaq_c,keqsld_all,mgasth_all,keqaq_s,so4f,staq_all &! input
            ! & ,prox,chrsld(isps),'so4f ' &! input 
            ! & ,dummy,dummy2,omega_error &! output
            ! & )
        ! if (omega_error) then
            ! flgback = .true.
            ! return 
        ! endif 
        ! domega_dso4f(isps,:) = dummy2
        
        
        dummy = 0d0
        domega_dpro_loc = 0d0
        domega_dso4f_loc = 0d0
        call calc_omega_v4( &
            & nz,nsp_aq,nsp_gas,nsp_aq_all,nsp_sld_all,nsp_gas_all,nsp_aq_cnst,nsp_gas_cnst & 
            & ,chraq,chraq_cnst,chraq_all,chrsld_all,chrgas,chrgas_cnst,chrgas_all &
            & ,maqx,maqc,mgasx,mgasc,mgasth_all,prox,so4f &
            & ,keqsld_all,keqgas_h,keqaq_h,keqaq_c,keqaq_s,keqaq_no3 &
            & ,staq_all,stgas_all &
            & ,chrsld(isps) &
            & ,domega_dmaq_all,domega_dmgas_all,domega_dpro_loc,domega_dso4f_loc &! output
            & ,dummy,omega_error &! output
            & )
        if (omega_error) then
            flgback = .true.
            return 
        endif 
        omega(isps,:) = dummy
        domega_dpro(isps,:) = domega_dpro_loc
        domega_dso4f(isps,:) = domega_dso4f_loc
        
        ! dummy = 0d0
        ! call calc_omega_v4( &
            ! & nz,nsp_aq,nsp_gas,nsp_aq_all,nsp_sld_all,nsp_gas_all,nsp_aq_cnst,nsp_gas_cnst & 
            ! & ,chraq,chraq_cnst,chraq_all,chrsld_all,chrgas,chrgas_cnst,chrgas_all &
            ! & ,maqx,maqc,mgasx,mgasc,mgasth_all,prox+dconc,so4f &
            ! & ,keqsld_all,keqgas_h,keqaq_h,keqaq_c,keqaq_s,keqaq_no3 &
            ! & ,staq_all,stgas_all &
            ! & ,chrsld(isps) &
            ! & ,domega_dmaq_all,domega_dmgas_all,domega_dpro_loc,domega_dso4f_loc &! output
            ! & ,dummy,omega_error &! output
            ! & )
        ! if (omega_error) then
            ! flgback = .true.
            ! return 
        ! endif 
        ! domega_dpro(isps,:) = (dummy - omega(isps,:))/dconc
        
        ! dummy = 0d0
        ! call calc_omega_v4( &
            ! & nz,nsp_aq,nsp_gas,nsp_aq_all,nsp_sld_all,nsp_gas_all,nsp_aq_cnst,nsp_gas_cnst & 
            ! & ,chraq,chraq_cnst,chraq_all,chrsld_all,chrgas,chrgas_cnst,chrgas_all &
            ! & ,maqx,maqc,mgasx,mgasc,mgasth_all,prox,so4f+dconc &
            ! & ,keqsld_all,keqgas_h,keqaq_h,keqaq_c,keqaq_s,keqaq_no3 &
            ! & ,staq_all,stgas_all &
            ! & ,chrsld(isps) &
            ! & ,domega_dmaq_all,domega_dmgas_all,domega_dpro_loc,domega_dso4f_loc &! output
            ! & ,dummy,omega_error &! output
            ! & )
        ! if (omega_error) then
            ! flgback = .true.
            ! return 
        ! endif 
        ! domega_dso4f(isps,:) = (dummy - omega(isps,:))/dconc
        
        do ispa = 1, nsp_aq
            if (any (chraq_ph == chraq(ispa)) .or. staq(isps,ispa)/=0d0 ) then 
                
                ! dummy = 0d0
                ! dummy2 = 0d0
                ! call calc_omega_dev_v2( &
                    ! & nz,nsp_aq,nsp_gas,nsp_aq_all,nsp_sld_all,nsp_gas_all,nsp_aq_cnst,nsp_gas_cnst &! input 
                    ! & ,chraq,chraq_cnst,chraq_all,chrsld_all,chrgas,chrgas_cnst,chrgas_all &!input
                    ! & ,maqx,maqc,mgasx,mgasc,keqgas_h,keqaq_h,keqaq_c,keqsld_all,mgasth_all,keqaq_s,so4f,staq_all &! input
                    ! & ,prox,chrsld(isps),chraq(ispa) &! input 
                    ! & ,dummy,dummy2,omega_error &! output
                    ! & )
                ! if (omega_error) then
                    ! flgback = .true.
                    ! return 
                ! endif 
                
                ! domega_dmaq(isps,ispa,:) = dummy2 + ( &
                    ! & domega_dpro(isps,:)*dprodmaq(ispa,:) &
                    ! & +domega_dso4f(isps,:)*dso4fdmaq(ispa,:) &
                    ! & )
                ! dmaq = 0d0
                ! dmaq(ispa,:) = dconc
                ! dummy = 0d0
                ! call calc_omega_v4( &
                    ! & nz,nsp_aq,nsp_gas,nsp_aq_all,nsp_sld_all,nsp_gas_all,nsp_aq_cnst,nsp_gas_cnst & 
                    ! & ,chraq,chraq_cnst,chraq_all,chrsld_all,chrgas,chrgas_cnst,chrgas_all &
                    ! & ,maqx+dmaq,maqc,mgasx,mgasc,mgasth_all,prox,so4f &
                    ! & ,keqsld_all,keqgas_h,keqaq_h,keqaq_c,keqaq_s,keqaq_no3 &
                    ! & ,staq_all,stgas_all &
                    ! & ,chrsld(isps) &
                    ! & ,dummy,omega_error &! output
                    ! & )
                ! if (omega_error) then
                    ! flgback = .true.
                    ! return 
                ! endif 
                ! domega_dmaq(isps,ispa,:) = (dummy - omega(isps,:))/dconc + ( &
                    ! & domega_dpro(isps,:)*dprodmaq(ispa,:) &
                    ! & +domega_dso4f(isps,:)*dso4fdmaq(ispa,:) &
                    ! & )
                domega_dmaq(isps,ispa,:) = domega_dmaq_all(findloc(chraq_all,chraq(ispa),dim=1),:)+ ( &
                    & domega_dpro(isps,:)*dprodmaq(ispa,:) &
                    & +domega_dso4f(isps,:)*dso4fdmaq(ispa,:) &
                    & )
                
                
            endif 
        enddo
        do ispg = 1, nsp_gas
            if (any (chrgas_ph == chrgas(ispg)) .or. stgas(isps,ispg)/=0d0) then 
                
                ! dummy = 0d0
                ! dummy2 = 0d0
                ! call calc_omega_dev_v2( &
                    ! & nz,nsp_aq,nsp_gas,nsp_aq_all,nsp_sld_all,nsp_gas_all,nsp_aq_cnst,nsp_gas_cnst &! input 
                    ! & ,chraq,chraq_cnst,chraq_all,chrsld_all,chrgas,chrgas_cnst,chrgas_all &!input
                    ! & ,maqx,maqc,mgasx,mgasc,keqgas_h,keqaq_h,keqaq_c,keqsld_all,mgasth_all,keqaq_s,so4f,staq_all &! input
                    ! & ,prox,chrsld(isps),chrgas(ispg) &! input 
                    ! & ,dummy,dummy2,omega_error &! output
                    ! & )
                ! if (omega_error) then
                    ! flgback = .true.
                    ! return 
                ! endif 
                
                ! domega_dmgas(isps,ispg,:) = dummy2 + ( &
                    ! & domega_dpro(isps,:)*dprodmgas(ispg,:) &
                    ! & +domega_dso4f(isps,:)*dso4fdmgas(ispg,:) &
                    ! & )
                ! dmgas = 0d0
                ! dmgas(ispg,:) = dconc
                ! dummy = 0d0
                ! call calc_omega_v4( &
                    ! & nz,nsp_aq,nsp_gas,nsp_aq_all,nsp_sld_all,nsp_gas_all,nsp_aq_cnst,nsp_gas_cnst & 
                    ! & ,chraq,chraq_cnst,chraq_all,chrsld_all,chrgas,chrgas_cnst,chrgas_all &
                    ! & ,maqx,maqc,mgasx+dmgas,mgasc,mgasth_all,prox,so4f &
                    ! & ,keqsld_all,keqgas_h,keqaq_h,keqaq_c,keqaq_s,keqaq_no3 &
                    ! & ,staq_all,stgas_all &
                    ! & ,chrsld(isps) &
                    ! & ,dummy,omega_error &! output
                    ! & )
                ! if (omega_error) then
                    ! flgback = .true.
                    ! return 
                ! endif 
                ! domega_dmgas(isps,ispg,:) = (dummy - omega(isps,:))/dconc + ( &
                    ! & domega_dpro(isps,:)*dprodmgas(ispg,:) &
                    ! & +domega_dso4f(isps,:)*dso4fdmgas(ispg,:) &
                    ! & )
                domega_dmgas(isps,ispg,:) = domega_dmgas_all(findloc(chrgas_all,chrgas(ispg),dim=1),:)+ ( &
                    & domega_dpro(isps,:)*dprodmgas(ispg,:) &
                    & +domega_dso4f(isps,:)*dso4fdmgas(ispg,:) &
                    & )
            endif 
        enddo
    enddo 
    
    
    ! print *,'omega',omega(findloc(chrsld,'gt',dim=1),:)
    ! print *
    ! print *,'domega_dmaq',domega_dmaq(findloc(chrsld,'gt',dim=1),:,:)
    ! print *
    ! print *,'domega_dmgas',domega_dmgas(findloc(chrsld,'gt',dim=1),:,:)
    
    ! adding reactions that are not based on dis/prec of minerals
    rxnext = 0d0
    drxnext_dpro = 0d0
    drxnext_dso4f = 0d0
    drxnext_dmaq = 0d0
    drxnext_dmgas = 0d0
    drxnext_dmsld = 0d0
    
    do irxn=1,nrxn_ext
        dummy = 0d0
        dummy2 = 0d0
        call calc_rxn_ext_dev_2( &
            & nz,nrxn_ext_all,nsp_gas_all,nsp_aq_all,nsp_gas,nsp_aq,nsp_aq_cnst,nsp_gas_cnst  &!input
            & ,chrrxn_ext_all,chrgas,chrgas_all,chrgas_cnst,chraq,chraq_all,chraq_cnst &! input
            & ,poro,sat,maqx,maqc,mgasx,mgasc,mgasth_all,maqth_all,krxn1_ext_all,krxn2_ext_all &! input
            & ,nsp_sld,nsp_sld_cnst,chrsld,chrsld_cnst,msldx,msldc,rho_grain,kw &!input
            & ,rg,tempk_0,tc &!input
            & ,nsp_sld_all,chrsld_all,msldth_all,mv_all,hr,prox,keqgas_h,keqaq_h,keqaq_c,keqaq_s,so4f &! input
            & ,chrrxn_ext(irxn),'pro  ' &! input 
            & ,dummy,dummy2,rxnext_error &! output
            & )
        if (rxnext_error) then
            flgback = .true.
            return 
        endif 
        rxnext(irxn,:) = dummy
        drxnext_dpro(irxn,:) = dummy2
        
        dummy = 0d0
        dummy2 = 0d0
        call calc_rxn_ext_dev_2( &
            & nz,nrxn_ext_all,nsp_gas_all,nsp_aq_all,nsp_gas,nsp_aq,nsp_aq_cnst,nsp_gas_cnst  &!input
            & ,chrrxn_ext_all,chrgas,chrgas_all,chrgas_cnst,chraq,chraq_all,chraq_cnst &! input
            & ,poro,sat,maqx,maqc,mgasx,mgasc,mgasth_all,maqth_all,krxn1_ext_all,krxn2_ext_all &! input
            & ,nsp_sld,nsp_sld_cnst,chrsld,chrsld_cnst,msldx,msldc,rho_grain,kw &!input
            & ,rg,tempk_0,tc &!input
            & ,nsp_sld_all,chrsld_all,msldth_all,mv_all,hr,prox,keqgas_h,keqaq_h,keqaq_c,keqaq_s,so4f &! input
            & ,chrrxn_ext(irxn),'so4f ' &! input 
            & ,dummy,dummy2,rxnext_error &! output
            & )
        if (rxnext_error) then
            flgback = .true.
            return 
        endif 
        drxnext_dso4f(irxn,:) = dummy2
        
        do ispg=1,nsp_gas
            if (stgas_dext(irxn,ispg)==0d0) cycle
            
            dummy = 0d0
            dummy2 = 0d0
            call calc_rxn_ext_dev_2( &
                & nz,nrxn_ext_all,nsp_gas_all,nsp_aq_all,nsp_gas,nsp_aq,nsp_aq_cnst,nsp_gas_cnst  &!input
                & ,chrrxn_ext_all,chrgas,chrgas_all,chrgas_cnst,chraq,chraq_all,chraq_cnst &! input
                & ,poro,sat,maqx,maqc,mgasx,mgasc,mgasth_all,maqth_all,krxn1_ext_all,krxn2_ext_all &! input
                & ,nsp_sld,nsp_sld_cnst,chrsld,chrsld_cnst,msldx,msldc,rho_grain,kw &!input
                & ,rg,tempk_0,tc &!input
                & ,nsp_sld_all,chrsld_all,msldth_all,mv_all,hr,prox,keqgas_h,keqaq_h,keqaq_c,keqaq_s,so4f &! input
                & ,chrrxn_ext(irxn),chrgas(ispg) &! input 
                & ,dummy,dummy2,rxnext_error &! output
                & )
            if (rxnext_error) then
                flgback = .true.
                return 
            endif 
            drxnext_dmgas(irxn,ispg,:) = dummy2 + (&
                & + drxnext_dpro(irxn,:)*dprodmgas(ispg,:) &
                & + drxnext_dso4f(irxn,:)*dso4fdmgas(ispg,:) &
                & )
        enddo 
        
        do ispa=1,nsp_aq
            if (staq_dext(irxn,ispa)==0d0) cycle
            
            dummy = 0d0
            dummy2 = 0d0
            call calc_rxn_ext_dev_2( &
                & nz,nrxn_ext_all,nsp_gas_all,nsp_aq_all,nsp_gas,nsp_aq,nsp_aq_cnst,nsp_gas_cnst  &!input
                & ,chrrxn_ext_all,chrgas,chrgas_all,chrgas_cnst,chraq,chraq_all,chraq_cnst &! input
                & ,poro,sat,maqx,maqc,mgasx,mgasc,mgasth_all,maqth_all,krxn1_ext_all,krxn2_ext_all &! input
                & ,nsp_sld,nsp_sld_cnst,chrsld,chrsld_cnst,msldx,msldc,rho_grain,kw &!input
                & ,rg,tempk_0,tc &!input
                & ,nsp_sld_all,chrsld_all,msldth_all,mv_all,hr,prox,keqgas_h,keqaq_h,keqaq_c,keqaq_s,so4f &! input
                & ,chrrxn_ext(irxn),chraq(ispa) &! input 
                & ,dummy,dummy2,rxnext_error &! output
                & )
            if (rxnext_error) then
                flgback = .true.
                return 
            endif 
            drxnext_dmaq(irxn,ispa,:) = dummy2 + ( &
                & + drxnext_dpro(irxn,:)*dprodmaq(ispa,:) &
                & + drxnext_dso4f(irxn,:)*dso4fdmaq(ispa,:) &
                & )
        enddo 
        
        do isps=1,nsp_sld
            if (stsld_dext(irxn,isps)==0d0) cycle
            
            dummy = 0d0
            dummy2 = 0d0
            call calc_rxn_ext_dev_2( &
                & nz,nrxn_ext_all,nsp_gas_all,nsp_aq_all,nsp_gas,nsp_aq,nsp_aq_cnst,nsp_gas_cnst  &!input
                & ,chrrxn_ext_all,chrgas,chrgas_all,chrgas_cnst,chraq,chraq_all,chraq_cnst &! input
                & ,poro,sat,maqx,maqc,mgasx,mgasc,mgasth_all,maqth_all,krxn1_ext_all,krxn2_ext_all &! input
                & ,nsp_sld,nsp_sld_cnst,chrsld,chrsld_cnst,msldx,msldc,rho_grain,kw &!input
                & ,rg,tempk_0,tc &!input
                & ,nsp_sld_all,chrsld_all,msldth_all,mv_all,hr,prox,keqgas_h,keqaq_h,keqaq_c,keqaq_s,so4f &! input
                & ,chrrxn_ext(irxn),chrsld(isps) &! input 
                & ,dummy,dummy2,rxnext_error &! output
                & )
            if (rxnext_error) then
                flgback = .true.
                return 
            endif 
            drxnext_dmsld(irxn,isps,:) = dummy2
        enddo 
    enddo 
    
    ! gas tansport
    khgas = 0d0
    khgasx = 0d0
    dkhgas_dmaq = 0d0
    dkhgas_dmgas = 0d0
    ! added
    dkhgas_dpro = 0d0
    dkhgas_dso4f = 0d0
    
    if (new_gassol) then 
        call calc_khgas_all( &
            & nz,nsp_aq_all,nsp_gas_all,nsp_gas,nsp_aq,nsp_aq_cnst,nsp_gas_cnst &
            & ,chraq_all,chrgas_all,chraq_cnst,chrgas_cnst,chraq,chrgas &
            & ,maq,mgas,maqx,mgasx,maqc,mgasc &
            & ,keqgas_h,keqaq_h,keqaq_c,keqaq_s,keqaq_no3  &
            & ,pro,prox,so4fprev,so4f &
            & ,khgas_all,khgasx_all,dkhgas_dpro_all,dkhgas_dso4f_all,dkhgas_dmaq_all,dkhgas_dmgas_all &!output
            & )
            
        do ispg=1,nsp_gas
            khgas(ispg,:)=khgas_all(findloc(chrgas_all,chrgas(ispg),dim=1),:)
            khgasx(ispg,:)=khgasx_all(findloc(chrgas_all,chrgas(ispg),dim=1),:)
            dkhgas_dpro(ispg,:)=dkhgas_dpro_all(findloc(chrgas_all,chrgas(ispg),dim=1),:)
            dkhgas_dso4f(ispg,:)=dkhgas_dso4f_all(findloc(chrgas_all,chrgas(ispg),dim=1),:)
            do ispa=1,nsp_aq
                dkhgas_dmaq(ispg,ispa,:)= &
                    & dkhgas_dmaq_all(findloc(chrgas_all,chrgas(ispg),dim=1),findloc(chraq_all,chraq(ispa),dim=1),:) &
                    & + dkhgas_dpro(ispg,:)*dprodmaq(ispa,:) &
                    & + dkhgas_dso4f(ispg,:)*dso4fdmaq(ispa,:)
            enddo 
            do ispg2=1,nsp_gas
                dkhgas_dmgas(ispg,ispg2,:)= &
                    & dkhgas_dmgas_all(findloc(chrgas_all,chrgas(ispg),dim=1),findloc(chrgas_all,chrgas(ispg2),dim=1),:) &
                    & + dkhgas_dpro(ispg,:)*dprodmgas(ispg2,:) &
                    & + dkhgas_dso4f(ispg,:)*dso4fdmgas(ispg2,:)
            enddo 
        enddo 
    endif
    
    dgas = 0d0
    ddgas_dmaq = 0d0
    ddgas_dmgas = 0d0
    
    agas = 0d0
    agasx = 0d0
    dagas_dmaq = 0d0
    dagas_dmgas = 0d0
    
    do ispg = 1, nsp_gas
        
        if (.not. new_gassol) then ! old way to calc solubility (to be removed?)
            select case (trim(adjustl(chrgas(ispg))))
                case('pco2')
                    khgas(ispg,:) = kco2*(1d0+k1/pro + k1*k2/pro/pro) ! previous value; should not change through iterations 
                    khgasx(ispg,:) = kco2*(1d0+k1/prox + k1*k2/prox/prox)
            
                    dkhgas_dpro(ispg,:) = kco2*(k1*(-1d0)/prox**2d0 + k1*k2*(-2d0)/prox**3d0)
                case('po2')
                    khgas(ispg,:) = kho ! previous value; should not change through iterations 
                    khgasx(ispg,:) = kho
            
                    dkhgas_dpro(ispg,:) = 0d0
                case('pnh3')
                    khgas(ispg,:) = knh3*(1d0+pro/k1nh3) ! previous value; should not change through iterations 
                    khgasx(ispg,:) = knh3*(1d0+prox/k1nh3)
            
                    dkhgas_dpro(ispg,:) = knh3*(1d0/k1nh3)
                case('pn2o')
                    khgas(ispg,:) = kn2o ! previous value; should not change through iterations 
                    khgasx(ispg,:) = kn2o
            
                    dkhgas_dpro(ispg,:) = 0d0
            endselect 
        endif 
        
        dgas(ispg,:) = ucv*poro*(1.0d0-sat)*1d3*torg*dgasg(ispg)+poro*sat*khgasx(ispg,:)*1d3*tora*dgasa(ispg)
        dgasi(ispg) = ucv*1d3*dgasg(ispg) 
        
        agas(ispg,:)= ucv*poroprev*(1.0d0-sat)*1d3+poroprev*sat*khgas(ispg,:)*1d3
        agasx(ispg,:)= ucv*poro*(1.0d0-sat)*1d3+poro*sat*khgasx(ispg,:)*1d3
        
        do ispa = 1,nsp_aq 
            if (.not. new_gassol) dkhgas_dmaq(ispg,ispa,:) = dkhgas_dpro(ispg,:)*dprodmaq(ispa,:) ! old way to calc solubility (to be removed?)
            ddgas_dmaq(ispg,ispa,:) = poro*sat*dkhgas_dmaq(ispg,ispa,:)*1d3*tora*dgasa(ispg)
            dagas_dmaq(ispg,ispa,:) =  poro*sat*dkhgas_dmaq(ispg,ispa,:)*1d3
        enddo 
        
        do ispg2 = 1,nsp_gas 
            if (.not. new_gassol) dkhgas_dmgas(ispg,ispg2,:) = dkhgas_dpro(ispg,:)*dprodmgas(ispg2,:) ! old way to calc solubility (to be removed?)
            ddgas_dmgas(ispg,ispg2,:) = poro*sat*dkhgas_dmgas(ispg,ispg2,:)*1d3*tora*dgasa(ispg)
            dagas_dmgas(ispg,ispg2,:) =  poro*sat*dkhgas_dmgas(ispg,ispg2,:)*1d3
        enddo 
    enddo 
    
    ! sld phase reactions
    
    rxnsld = 0d0
    drxnsld_dmsld = 0d0
    drxnsld_dmaq = 0d0
    drxnsld_dmgas = 0d0
    
    call sld_rxn( &
        & nz,nsp_sld,nsp_aq,nsp_gas,msld_seed,hr,poro,mv,ksld,omega,nonprec,msldx,dz &! input 
        & ,dksld_dmaq,domega_dmaq,dksld_dmgas,domega_dmgas,precstyle &! input
        & ,msld,msldth,dt,sat,maq,maqth,agas,mgas,mgasth,staq,stgas &! input
        & ,rxnsld,drxnsld_dmsld,drxnsld_dmaq,drxnsld_dmgas &! output
        & ) 
    
    ! gas reactions 
    
    rxngas = 0d0
    drxngas_dmaq = 0d0
    drxngas_dmsld = 0d0
    drxngas_dmgas = 0d0
        
    do ispg = 1, nsp_gas
        do isps = 1, nsp_sld
            rxngas(ispg,:) =  rxngas(ispg,:) + (&
                ! & stgas(isps,ispg)*ksld(isps,:)*poro*hr*mv(isps)*1d-6*msldx(isps,:)*(1d0-omega(isps,:)) &
                ! & *merge(0d0,1d0,1d0-omega(isps,:)*nonprec(isps,:) < 0d0) &
                & + stgas(isps,ispg)*rxnsld(isps,:) &
                & )
            drxngas_dmsld(ispg,isps,:) =  drxngas_dmsld(ispg,isps,:) + (&
                ! & stgas(isps,ispg)*ksld(isps,:)*poro*hr*mv(isps)*1d-6*1d0*(1d0-omega(isps,:)) &
                ! & *merge(0d0,1d0,1d0-omega(isps,:)*nonprec(isps,:) < 0d0) &
                & + stgas(isps,ispg)*drxnsld_dmsld(isps,:) &
                & )
            do ispg2 = 1,nsp_gas
                drxngas_dmgas(ispg,ispg2,:) =  drxngas_dmgas(ispg,ispg2,:) + (&
                    ! & stgas(isps,ispg)*ksld(isps,:)*poro*hr*mv(isps)*1d-6*msldx(isps,:)*(-domega_dmgas(isps,ispg2,:)) &
                    ! & *merge(0d0,1d0,1d0-omega(isps,:)*nonprec(isps,:) < 0d0) &
                    ! & + stgas(isps,ispg)*dksld_dmgas(isps,ispg2,:)*poro*hr*mv(isps)*1d-6*msldx(isps,:)*(1d0-omega(isps,:)) &
                    ! & *merge(0d0,1d0,1d0-omega(isps,:)*nonprec(isps,:) < 0d0) &
                    & + stgas(isps,ispg)*drxnsld_dmgas(isps,ispg2,:) &
                    & )
            enddo 
            do ispa = 1,nsp_aq
                drxngas_dmaq(ispg,ispa,:) =  drxngas_dmaq(ispg,ispa,:) + ( &
                    ! & stgas(isps,ispg)*ksld(isps,:)*poro*hr*mv(isps)*1d-6*msldx(isps,:)*(-domega_dmaq(isps,ispa,:)) &
                    ! & *merge(0d0,1d0,1d0-omega(isps,:)*nonprec(isps,:) < 0d0) &
                    ! & + stgas(isps,ispg)*dksld_dmaq(isps,ispa,:)*poro*hr*mv(isps)*1d-6*msldx(isps,:)*(1d0-omega(isps,:)) &
                    ! & *merge(0d0,1d0,1d0-omega(isps,:)*nonprec(isps,:) < 0d0) &
                    & + stgas(isps,ispg)*drxnsld_dmaq(isps,ispa,:) &
                    & )
            enddo 
        enddo 
    enddo 
            
    if (.not.sld_enforce) then 

        do iz = 1, nz  !================================
            
            do isps = 1, nsp_sld
            
                row = nsp3*(iz-1)+isps
                
                k_tmp = ksld(isps,iz)
                mv_tmp = mv(isps)
                omega_tmp = omega(isps,iz)
                omega_tmp_th = omega_tmp*nonprec(isps,iz)
                m_tmp = msldx(isps,iz) 
                mth_tmp = msldth(isps) 
                mi_tmp = msldi(isps)
                mp_tmp = msldx(isps,min(nz,iz+1))
                msupp_tmp = msldsupp(isps,iz) 
                rxn_ext_tmp = sum(stsld_ext(:,isps)*rxnext(:,iz))
                mprev_tmp = msld(isps,iz)  
                w_tmp = w(iz) 
                wp_tmp = w(min(nz,iz+1)) 
                sporo_tmp = 1d0-poro(iz)
                sporop_tmp = 1d0-poro(min(nz,iz+1)) 
                sporoprev_tmp = 1d0-poroprev(iz)
                mn_tmp = msldx(isps,max(1,iz-1))
                wn_tmp = w(max(1,iz-1))
                sporon_tmp = 1d0-poro(max(1,iz-1))
                
                if (iz==1) then 
                    mn_tmp = 0d0
                    wn_tmp = 0d0
                    sporon_tmp = 0d0
                endif 
                
                if (iz==nz) then 
                    mp_tmp = mi_tmp
                    wp_tmp = w_btm 
                    sporop_tmp = 1d0- poroi
                endif 
                
                if (msldunit == 'blk') then 
                    sporo_tmp = 1d0
                    sporop_tmp = 1d0
                    sporon_tmp = 1d0
                    sporoprev_tmp = 1d0
                endif 

                amx3(row,row) = ( &
                    & 1d0 *  sporo_tmp /merge(1d0,dt,dt_norm)     &
                    ! & + adf(iz)*up(iz)*sporo_tmp*w_tmp/dz(iz)*merge(dt,1d0,dt_norm)    &
                    ! & - adf(iz)*dwn(iz)*sporo_tmp*w_tmp/dz(iz)*merge(dt,1d0,dt_norm)    &
                    & + sporo_tmp*w_tmp/dz(iz)*merge(dt,1d0,dt_norm)    &
                    & + drxnsld_dmsld(isps,iz)*merge(dt,1d0,dt_norm) &
                    & - sum(stsld_ext(:,isps)*drxnext_dmsld(:,isps,iz))*merge(dt,1d0,dt_norm) &
                    & ) &
                    & * merge(1.0d0,m_tmp,m_tmp<mth_tmp*sw_red)

                ymx3(row) = ( &
                    & ( sporo_tmp*m_tmp - sporoprev_tmp*mprev_tmp )/merge(1d0,dt,dt_norm) &
                    & - ( sporop_tmp*wp_tmp*mp_tmp - sporo_tmp*w_tmp* m_tmp)/dz(iz)*merge(dt,1d0,dt_norm)  &
                    ! & - adf(iz)*up(iz)*( sporop_tmp*wp_tmp*mp_tmp - sporo_tmp*w_tmp* m_tmp)/dz(iz)*merge(dt,1d0,dt_norm)  &
                    ! & - adf(iz)*dwn(iz)*( sporo_tmp*w_tmp* m_tmp - sporon_tmp*wn_tmp*mn_tmp )/dz(iz)*merge(dt,1d0,dt_norm)  &
                    ! & - adf(iz)*cnr(iz)*( sporop_tmp*wp_tmp*mp_tmp - sporon_tmp*wn_tmp*mn_tmp )/dz(iz)*merge(dt,1d0,dt_norm)  &
                    & + rxnsld(isps,iz)*merge(dt,1d0,dt_norm) &
                    & -msupp_tmp*merge(dt,1d0,dt_norm)  &
                    & -rxn_ext_tmp*merge(dt,1d0,dt_norm)  &
                    & ) &
                    & *merge(0.0d0,1d0,m_tmp<mth_tmp*sw_red)
                    
                if (iz/=nz) amx3(row,row+nsp3) = ( &
                    & (- sporop_tmp*wp_tmp/dz(iz))*merge(dt,1d0,dt_norm) &
                    ! & (- adf(iz)*up(iz)* sporop_tmp*wp_tmp/dz(iz))*merge(dt,1d0,dt_norm) &
                    ! & +(- adf(iz)*cnr(iz)* sporop_tmp*wp_tmp/dz(iz))*merge(dt,1d0,dt_norm) &
                    & ) &
                    & *merge(1.0d0,mp_tmp,m_tmp<mth_tmp*sw_red)
                    
                ! if (iz/=1) amx3(row,row-nsp3) = ( &
                    ! & (+ adf(iz)*dwn(iz)* sporon_tmp*wn_tmp/dz(iz))*merge(dt,1d0,dt_norm) &
                    ! & +(+ adf(iz)*cnr(iz)* sporon_tmp*wn_tmp/dz(iz))*merge(dt,1d0,dt_norm) &
                    ! & ) &
                    ! & *merge(1.0d0,mn_tmp,m_tmp<mth_tmp*sw_red)
                
                do ispa = 1, nsp_aq
                    col = nsp3*(iz-1) + nsp_sld + ispa
                    
                    amx3(row,col ) = ( &
                        & + drxnsld_dmaq(isps,ispa,iz)*merge(dt,1d0,dt_norm) &
                        & - sum(stsld_ext(:,isps)*drxnext_dmaq(:,ispa,iz))*merge(dt,1d0,dt_norm) &
                        & ) &
                        & *maqx(ispa,iz) &
                        & *merge(0.0d0,1d0,m_tmp<mth_tmp*sw_red)
                enddo 
                
                do ispg = 1, nsp_gas 
                    col = nsp3*(iz-1)+nsp_sld + nsp_aq + ispg

                    amx3(row,col) = ( &
                        & + drxnsld_dmgas(isps,ispg,iz)*merge(dt,1d0,dt_norm) &
                        & - sum(stsld_ext(:,isps)*drxnext_dmgas(:,ispg,iz))*merge(dt,1d0,dt_norm) &
                        & ) &
                        & *mgasx(ispg,iz) &
                        & *merge(0.0d0,1d0,m_tmp<mth_tmp*sw_red)
                enddo 
                
                do isps2 = 1,nsp_sld 
                    if (isps2 == isps) cycle
                    col = nsp3*(iz-1)+ isps2

                    amx3(row,col) = ( &
                        & - sum(stsld_ext(:,isps)*drxnext_dmsld(:,isps2,iz))*merge(dt,1d0,dt_norm) &
                        & ) &
                        & *msldx(isps2,iz) &
                        & *merge(0.0d0,1d0,m_tmp<mth_tmp*sw_red)
                enddo 

#ifdef calcw_full
                col =  nsp3*(iz-1)+ nsp3
                amx3(row,col) = ( &
                    & - ( - sporo_tmp* m_tmp)/dz(iz)*merge(dt,1d0,dt_norm)  &
                    & ) &
                    ! & * w_tmp &
                    & *merge(0.0d0,1d0,m_tmp<mth_tmp*sw_red)
                    
                if (iz/=nz) amx3(row,col+nsp3) = ( &
                    & (- sporop_tmp*mp_tmp/dz(iz))*merge(dt,1d0,dt_norm) &
                    ! & (- adf(iz)*up(iz)* sporop_tmp*wp_tmp/dz(iz))*merge(dt,1d0,dt_norm) &
                    ! & +(- adf(iz)*cnr(iz)* sporop_tmp*wp_tmp/dz(iz))*merge(dt,1d0,dt_norm) &
                    & ) &
                    ! & *wp_tmp  &
                    & *merge(0.0d0,1d0,m_tmp<mth_tmp*sw_red)
#endif 
                ! diffusion terms are filled with transition matrices 
                ! if (turbo2(isps).or.labs(isps)) then
                    ! do iiz = 1, nz
                        ! col = nsp3*(iiz-1)+isps
                        ! if (trans(iiz,iz,isps)==0d0) cycle
                        ! amx3(row,col) = amx3(row,col) &
                            ! & - trans(iiz,iz,isps)/dz(iz)*dz(iiz)*msldx(isps,iiz)
                        ! ymx3(row) = ymx3(row) &
                            ! & - trans(iiz,iz,isps)/dz(iz)*dz(iiz)*msldx(isps,iiz)
                            
                        ! flx_sld(isps,idif,iz) = flx_sld(isps,idif,iz) + ( &
                            ! & - trans(iiz,iz,isps)/dz(iz)*dz(iiz)*msldx(isps,iiz) &
                            ! & )
                    ! enddo
                ! else
                    ! do iiz = 1, nz
                        ! col = nsp3*(iiz-1)+isps
                        ! if (trans(iiz,iz,isps)==0d0) cycle
                            
                        ! amx3(row,col) = amx3(row,col) -trans(iiz,iz,isps)/dz(iz)*msldx(isps,iiz) &
                            ! & *merge(0.0d0,1d0,m_tmp<mth_tmp*sw_red)
                        ! ymx3(row) = ymx3(row) - trans(iiz,iz,isps)/dz(iz)*msldx(isps,iiz) &
                            ! & *merge(0.0d0,1d0,m_tmp<mth_tmp*sw_red)
                            
                        ! flx_sld(isps,idif,iz) = flx_sld(isps,idif,iz) + ( &
                            ! & - trans(iiz,iz,isps)/dz(iz)*msldx(isps,iiz) &
                            ! & )
                    ! enddo
                ! endif
                
                ! modifications with porosity and dz are made in make_trans subroutine
                do iiz = 1, nz
                    col = nsp3*(iiz-1)+isps
                    if (trans(iiz,iz,isps)==0d0) cycle
                        
                    amx3(row,col) = amx3(row,col) - trans(iiz,iz,isps)*msldx(isps,iiz)* sporo(iiz)* merge(dt,1d0,dt_norm) &
                        & *merge(0.0d0,1d0,m_tmp<mth_tmp*sw_red)
                    ymx3(row) = ymx3(row) - trans(iiz,iz,isps)*msldx(isps,iiz)* sporo(iiz)* merge(dt,1d0,dt_norm) &
                        & *merge(0.0d0,1d0,m_tmp<mth_tmp*sw_red)
                        
                    flx_sld(isps,idif,iz) = flx_sld(isps,idif,iz) + ( &
                        & - trans(iiz,iz,isps)*msldx(isps,iiz)* sporo(iiz) &
                        & )
                enddo
                
                flx_sld(isps,itflx,iz) = ( &
                    & ( sporo_tmp*m_tmp- sporoprev_tmp*mprev_tmp)/dt &
                    & )
                flx_sld(isps,iadv,iz) = ( &
                    & - ( sporop_tmp*wp_tmp*mp_tmp - sporo_tmp*w_tmp* m_tmp)/dz(iz)  &
                    ! & - adf(iz)*up(iz)*( sporop_tmp*wp_tmp*mp_tmp - sporo_tmp*w_tmp* m_tmp)/dz(iz)  &
                    ! & - adf(iz)*dwn(iz)*( sporo_tmp*w_tmp* m_tmp - sporon_tmp*wn_tmp*mn_tmp )/dz(iz)  &
                    ! & - adf(iz)*cnr(iz)*( sporop_tmp*wp_tmp*mp_tmp - sporon_tmp*wn_tmp*mn_tmp )/dz(iz)  &
                    & )
                flx_sld(isps,irxn_sld(isps),iz) = ( &
                    & + rxnsld(isps,iz) &
                    & )
                flx_sld(isps,irain,iz) = (&
                    & - msupp_tmp  &
                    & )
                flx_sld(isps,irxn_ext(:),iz) = (&
                        & - stsld_ext(:,isps)*rxnext(:,iz)  &
                        & )
                flx_sld(isps,ires,iz) = sum(flx_sld(isps,:,iz))
                if (isnan(flx_sld(isps,ires,iz))) then 
                    print *,chrsld(isps),iz,(flx_sld(isps,iflx,iz),iflx=1,nflx)
                endif 
            enddo 
        end do  !================================
    
    endif 
    
#ifdef calcw_full
    do iz=1,nz
        row = nsp3*(iz-1) + nsp3
                
        w_tmp = w(iz) 
        wp_tmp = w(min(nz,iz+1)) 
        sporo_tmp = 1d0-poro(iz)
        sporop_tmp = 1d0-poro(min(nz,iz+1)) 
        sporoprev_tmp = 1d0-poroprev(iz)
        wn_tmp = w(max(1,iz-1))
        sporon_tmp = 1d0-poro(max(1,iz-1))
        
        if (iz==1) then 
            wn_tmp = 0d0
            sporon_tmp = 0d0
        endif 
        
        if (iz==nz) then 
            wp_tmp = w_btm 
            sporop_tmp = 1d0- poroi
        endif 
                
        ymx3(row) = ( &
            & ( sporo_tmp - sporoprev_tmp )/merge(1d0,dt,dt_norm) &
            & - ( sporop_tmp*wp_tmp - sporo_tmp*w_tmp)/dz(iz)*merge(dt,1d0,dt_norm)  &
            & ) 
            
        amx3(row,row) = amx3(row,row) + ( &
            & - (- sporo_tmp*1d0)/dz(iz)*merge(dt,1d0,dt_norm)  &
            & ) &
            ! & *w_tmp &
            & *1d0
            
        if (iz/=nz) amx3(row,row+nsp3) = amx3(row,row) + ( &
            & - ( sporop_tmp*1d0 )/dz(iz)*merge(dt,1d0,dt_norm)  &
            & ) &
            ! & *wp_tmp &
            & *1d0
            
        do isps = 1, nsp_sld
            
            col = nsp3*(iz-1)+isps
            
            k_tmp = ksld(isps,iz)
            mv_tmp = mv(isps)
            omega_tmp = omega(isps,iz)
            omega_tmp_th = omega_tmp*nonprec(isps,iz)
            m_tmp = msldx(isps,iz) 
            mth_tmp = msldth(isps) 
            mi_tmp = msldi(isps)
            mp_tmp = msldx(isps,min(nz,iz+1))
            msupp_tmp = msldsupp(isps,iz) 
            rxn_ext_tmp = sum(stsld_ext(:,isps)*rxnext(:,iz))
            mprev_tmp = msld(isps,iz)  

            ymx3(row) = ymx3(row) + ( &
                & + rxnsld(isps,iz)*merge(dt,1d0,dt_norm) &
                & -msupp_tmp*merge(dt,1d0,dt_norm)  &
                & -rxn_ext_tmp*merge(dt,1d0,dt_norm)  &
                & ) &
                & * mv(isps) * 1d-6 &
                & *merge(0.0d0,1d0,m_tmp<mth_tmp*sw_red)

            amx3(row,col) = amx3(row,col) + ( &  
                & + drxnsld_dmsld(isps,iz)*merge(dt,1d0,dt_norm) &
                & - sum(stsld_ext(:,isps)*drxnext_dmsld(:,isps,iz))*merge(dt,1d0,dt_norm) &
                & ) &
                & * mv(isps) * 1d-6 &
                & * merge(1.0d0,m_tmp,m_tmp<mth_tmp*sw_red)
                
            do iiz = 1, nz
                col = nsp3*(iiz-1)+isps
                ymx3(row) = ymx3(row) + ( &
                    & - trans(iiz,iz,isps)*msldx(isps,iiz)* sporo(iiz)* merge(dt,1d0,dt_norm) &
                    & ) &
                    & * mv(isps) * 1d-6 &
                    & *merge(0.0d0,1d0,m_tmp<mth_tmp*sw_red)
                
                amx3(row,col) = amx3(row,col) + ( &
                    & - trans(iiz,iz,isps)*msldx(isps,iiz)* sporo(iiz)* merge(dt,1d0,dt_norm) &
                    & ) &
                    & * mv(isps) * 1d-6 &
                    & *merge(0.0d0,1d0,m_tmp<mth_tmp*sw_red)
            enddo 
                
            do ispa = 1, nsp_aq
                col = nsp3*(iz-1) + nsp_sld + ispa
                
                amx3(row,col ) = amx3(row,col ) + ( &
                    & + drxnsld_dmaq(isps,ispa,iz)*merge(dt,1d0,dt_norm) &
                    & - sum(stsld_ext(:,isps)*drxnext_dmaq(:,ispa,iz))*merge(dt,1d0,dt_norm) &
                    & ) &
                    & *maqx(ispa,iz) &
                    & * mv(isps) * 1d-6 &
                    & *merge(0.0d0,1d0,m_tmp<mth_tmp*sw_red)
            enddo 
            
            do ispg = 1, nsp_gas 
                col = nsp3*(iz-1)+nsp_sld + nsp_aq + ispg

                amx3(row,col) = amx3(row,col ) + ( &
                    & + drxnsld_dmgas(isps,ispg,iz)*merge(dt,1d0,dt_norm) &
                    & - sum(stsld_ext(:,isps)*drxnext_dmgas(:,ispg,iz))*merge(dt,1d0,dt_norm) &
                    & ) &
                    & *mgasx(ispg,iz) &
                    & * mv(isps) * 1d-6 &
                    & *merge(0.0d0,1d0,m_tmp<mth_tmp*sw_red)
            enddo 
            
            do isps2 = 1,nsp_sld 
                if (isps2 == isps) cycle
                col = nsp3*(iz-1)+ isps2

                amx3(row,col) = amx3(row,col ) + ( &
                    & - sum(stsld_ext(:,isps)*drxnext_dmsld(:,isps2,iz))*merge(dt,1d0,dt_norm) &
                    & ) &
                    & *msldx(isps2,iz) &
                    & * mv(isps) * 1d-6 &
                    & *merge(0.0d0,1d0,m_tmp<mth_tmp*sw_red)
            enddo 
            
        enddo 
    
    
    enddo
#endif 
    

    do iz = 1, nz
        
        do ispa = 1, nsp_aq

            row = nsp3*(iz-1)+ nsp_sld*solve_sld + ispa
            
            d_tmp = daq(ispa)
            caq_tmp = maqx(ispa,iz)
            caq_tmp_prev = maq(ispa,iz)
            caq_tmp_p = maqx(ispa,min(nz,iz+1))
            caq_tmp_n = maqx(ispa,max(1,iz-1))
            caqth_tmp = maqth(ispa)
            caqi_tmp = maqi(ispa)
            caqsupp_tmp = maqsupp(ispa,iz) 
            rxn_ext_tmp = sum(staq_ext(:,ispa)*rxnext(:,iz))
            rxn_tmp = sum(staq(:,ispa)*rxnsld(:,iz))
            drxndisp_tmp = sum(staq(:,ispa)*drxnsld_dmaq(:,ispa,iz))
            
            if (iz==1) caq_tmp_n = caqi_tmp
                
            edif_tmp = 1d3*poro(iz)*sat(iz)*tora(iz)*d_tmp
            edif_tmp_p = 1d3*poro(min(iz+1,nz))*sat(min(iz+1,nz))*tora(min(iz+1,nz))*d_tmp
            edif_tmp_n = 1d3*poro(max(iz-1,1))*sat(max(iz-1,1))*tora(max(iz-1,1))*d_tmp

            amx3(row,row) = ( &
                & (poro(iz)*sat(iz)*1d3*1d0)/merge(1d0,dt,dt_norm)  &
                & -(0.5d0*(edif_tmp +edif_tmp_p)*merge(0d0,-1d0,iz==nz)/( 0.5d0*(dz(iz)+dz(min(nz,iz+1))) ) &
                & -0.5d0*(edif_tmp +edif_tmp_n)*(1d0)/( 0.5d0*(dz(iz)+dz(max(1,iz-1))) ))/dz(iz) &
                & *merge(dt,1d0,dt_norm) &
                & + poro(iz)*sat(iz)*1d3*v(iz)*(1d0)/dz(iz)*merge(dt,1d0,dt_norm) &
                & -drxndisp_tmp*merge(dt,1d0,dt_norm) &
                & - sum(staq_ext(:,ispa)*drxnext_dmaq(:,ispa,iz))*merge(dt,1d0,dt_norm) &
                & ) &
                & *merge(1.0d0,caq_tmp,caq_tmp<caqth_tmp*sw_red)

            ymx3(row) = ( &
                & (poro(iz)*sat(iz)*1d3*caq_tmp-poroprev(iz)*sat(iz)*1d3*caq_tmp_prev)/merge(1d0,dt,dt_norm)  &
                & -(0.5d0*(edif_tmp +edif_tmp_p)*(caq_tmp_p-caq_tmp)/(0.5d0*(dz(iz)+dz(min(nz,iz+1)))) &
                & -0.5d0*(edif_tmp +edif_tmp_n)*(caq_tmp-caq_tmp_n)/(0.5d0*(dz(iz)+dz(max(1,iz-1)))))/dz(iz) &
                & *merge(dt,1d0,dt_norm) &
                & + poro(iz)*sat(iz)*1d3*v(iz)*(caq_tmp-caq_tmp_n)/dz(iz)*merge(dt,1d0,dt_norm) &
                & - rxn_tmp*merge(dt,1d0,dt_norm) &
                & - caqsupp_tmp*merge(dt,1d0,dt_norm) &
                & - rxn_ext_tmp*merge(dt,1d0,dt_norm) &
                & ) &
                & *merge(0.0d0,1.0d0,caq_tmp<caqth_tmp*sw_red)   ! commented out (is this necessary?)

            if (iz/=1) then 
                amx3(row,row-nsp3) = ( &
                    & -(-0.5d0*(edif_tmp +edif_tmp_n)*(-1d0)/(0.5d0*(dz(iz)+dz(max(1,iz-1)))))/dz(iz) &
                    & *merge(dt,1d0,dt_norm) &
                    & + poro(iz)*sat(iz)*1d3*v(iz)*(-1d0)/dz(iz)*merge(dt,1d0,dt_norm) &
                    & ) &
                    & *caq_tmp_n &
                    & *merge(0.0d0,1.0d0,caq_tmp<caqth_tmp*sw_red)   ! commented out (is this necessary?)
            endif 
            
            if (iz/=nz) then 
                amx3(row,row+nsp3) = ( &
                    & -(0.5d0*(edif_tmp +edif_tmp_p)*(1d0)/(0.5d0*(dz(iz)+dz(min(nz,iz+1)))))/dz(iz) &
                    & *merge(dt,1d0,dt_norm) &
                    & ) &
                    & *caq_tmp_p &
                    & *merge(0.0d0,1.0d0,caq_tmp<caqth_tmp*sw_red)   ! commented out (is this necessary?)
            endif 
            
            if (.not.sld_enforce) then 
                do isps = 1, nsp_sld
                    col = nsp3*(iz-1)+ isps
                    
                    amx3(row, col) = (     & 
                        ! & - staq(isps,ispa)*ksld(isps,iz)*poro(iz)*hr(iz)*mv(isps)*1d-6*1d0*(1d0-omega(isps,iz)) &
                        ! & *merge(0d0,1d0,1d0-omega(isps,iz)*nonprec(isps,iz) < 0d0)*merge(dt,1d0,dt_norm)  &
                        & - staq(isps,ispa)*drxnsld_dmsld(isps,iz)*merge(dt,1d0,dt_norm) &
                        & - sum(staq_ext(:,ispa)*drxnext_dmsld(:,isps,iz))*merge(dt,1d0,dt_norm) &
                        & ) &
                        & *msldx(isps,iz) &
                        & *merge(0.0d0,1.0d0,caq_tmp<caqth_tmp*sw_red)   ! commented out (is this necessary?)
                enddo 
            endif  
            
            do ispa2 = 1, nsp_aq
                col = nsp3*(iz-1)+ nsp_sld*solve_sld + ispa2
                
                if (ispa2 == ispa) cycle
                
                amx3(row,col) = amx3(row,col) + (     & 
                    & - sum(staq(:,ispa)*drxnsld_dmaq(:,ispa2,iz))*merge(dt,1d0,dt_norm) &
                    & - sum(staq_ext(:,ispa)*drxnext_dmaq(:,ispa2,iz))*merge(dt,1d0,dt_norm) &
                    & ) &
                    & *maqx(ispa2,iz) &
                    & *merge(0.0d0,1.0d0,caq_tmp<caqth_tmp*sw_red)   ! commented out (is this necessary?)
            enddo 
            
            do ispg = 1, nsp_gas
                col = nsp3*(iz-1) + nsp_sld*solve_sld + nsp_aq + ispg
                
                amx3(row,col) = amx3(row,col) + (     & 
                    & - sum(staq(:,ispa)*drxnsld_dmgas(:,ispg,iz))*merge(dt,1d0,dt_norm) &
                    & - sum(staq_ext(:,ispa)*drxnext_dmgas(:,ispg,iz))*merge(dt,1d0,dt_norm) &
                    & ) &
                    & *mgasx(ispg,iz) &
                    & *merge(0.0d0,1.0d0,caq_tmp<caqth_tmp*sw_red)   ! commented out (is this necessary?)
            enddo 
                    
            flx_aq(ispa,itflx,iz) = (&
                & (poro(iz)*sat(iz)*1d3*caq_tmp-poroprev(iz)*sat(iz)*1d3*caq_tmp_prev)/dt  &
                & ) 
            flx_aq(ispa,iadv,iz) = (&
                & + poro(iz)*sat(iz)*1d3*v(iz)*(caq_tmp-caq_tmp_n)/dz(iz) &
                & ) 
            flx_aq(ispa,idif,iz) = (&
                & -(0.5d0*(edif_tmp +edif_tmp_p)*(caq_tmp_p-caq_tmp)/(0.5d0*(dz(iz)+dz(min(nz,iz+1)))) &
                & -0.5d0*(edif_tmp +edif_tmp_n)*(caq_tmp-caq_tmp_n)/(0.5d0*(dz(iz)+dz(max(1,iz-1)))))/dz(iz) &
                & ) 
            flx_aq(ispa,irxn_sld(:),iz) = (& 
                ! & -staq(:,ispa)*ksld(:,iz)*poro(iz)*hr(iz)*mv(:)*1d-6*msldx(:,iz)*(1d0-omega(:,iz)) &
                ! & *merge(0d0,1d0,1d0-omega(:,iz)*nonprec(:,iz) < 0d0) &
                & - staq(:,ispa)*rxnsld(:,iz) &
                & ) 
            flx_aq(ispa,irain,iz) = (&
                & - caqsupp_tmp &
                & ) 
            flx_aq(ispa,irxn_ext(:),iz) = (&
                & - staq_ext(:,ispa)*rxnext(:,iz) &
                & ) 
            flx_aq(ispa,ires,iz) = sum(flx_aq(ispa,:,iz))
            if (isnan(flx_aq(ispa,ires,iz))) then 
                print *,chraq(ispa),iz,(flx_aq(ispa,iflx,iz),iflx=1,nflx)
            endif 
            
            amx3(row,:) = amx3(row,:)*fact 
            ymx3(row) = ymx3(row)*fact 
        
        enddo 
        
    end do  ! ==============================
    
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!    pCO2 & pO2   !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    
    ! print *,drxngas_dmaq(findloc(chrgas,'pco2',dim=1),findloc(chraq,'ca',dim=1),:)
    
    do iz = 1, nz
        
        do ispg = 1, nsp_gas
        
            row = nsp3*(iz-1) + nsp_sld*solve_sld + nsp_aq + ispg
            
            pco2n_tmp = mgasx(ispg,max(1,iz-1))
            khco2n_tmp = khgasx(ispg,max(1,iz-1))
            edifn_tmp = dgas(ispg,max(1,iz-1))
            if (iz == 1) then 
                pco2n_tmp = mgasi(ispg)
                khco2n_tmp = khgasi(ispg)
                edifn_tmp = dgasi(ispg)
            endif 

            amx3(row,row) = ( &
                & (agasx(ispg,iz) + dagas_dmgas(ispg,ispg,iz)*mgasx(ispg,iz))/merge(1d0,dt,dt_norm) &
                & -( 0.5d0*(dgas(ispg,iz)+dgas(ispg,min(nz,iz+1)))*merge(0d0,-1d0,iz==nz)/(0.5d0*(dz(iz)+dz(min(nz,iz+1)))) &
                & +0.5d0*(ddgas_dmgas(ispg,ispg,iz))*(mgasx(ispg,min(nz,iz+1))-mgasx(ispg,iz))/(0.5d0*(dz(iz)+dz(min(nz,iz+1)))) &
                & - 0.5d0*(dgas(ispg,iz)+edifn_tmp)*(1d0)/(0.5d0*(dz(iz)+dz(max(1,iz-1)))) &
                & - 0.5d0*(ddgas_dmgas(ispg,ispg,iz))*(mgasx(ispg,iz)-pco2n_tmp)/(0.5d0*(dz(iz)+dz(max(1,iz-1)))) )/dz(iz)  &
                & *merge(dt,1d0,dt_norm) &
                & +poro(iz)*sat(iz)*v(iz)*1d3*(khgasx(ispg,iz)*1d0)/dz(iz)*merge(dt,1d0,dt_norm) &
                & +poro(iz)*sat(iz)*v(iz)*1d3*(dkhgas_dmgas(ispg,ispg,iz)*mgasx(ispg,iz))/dz(iz) *merge(dt,1d0,dt_norm) &
                & -sum(stgas_ext(:,ispg)*drxnext_dmgas(:,ispg,iz))*merge(dt,1d0,dt_norm) &
                & -drxngas_dmgas(ispg,ispg,iz)*merge(dt,1d0,dt_norm) &
                & ) &
                & *merge(1.0d0,mgasx(ispg,iz),mgasx(ispg,iz)<mgasth(ispg)*sw_red)
            
            ymx3(row) = ( &
                & (agasx(ispg,iz)*mgasx(ispg,iz)-agas(ispg,iz)*mgas(ispg,iz))/merge(1d0,dt,dt_norm) &
                & -( 0.5d0*(dgas(ispg,iz)+dgas(ispg,min(nz,iz+1)))*(mgasx(ispg,min(nz,iz+1))-mgasx(ispg,iz)) &
                &       /(0.5d0*(dz(iz)+dz(min(nz,iz+1)))) &
                & - 0.5d0*(dgas(ispg,iz)+edifn_tmp)*(mgasx(ispg,iz)-pco2n_tmp)/(0.5d0*(dz(iz)+dz(max(1,iz-1)))))/dz(iz)  &
                & *merge(dt,1d0,dt_norm) &
                & +poro(iz)*sat(iz)*v(iz)*1d3*(khgasx(ispg,iz)*mgasx(ispg,iz)-khco2n_tmp*pco2n_tmp)/dz(iz)*merge(dt,1d0,dt_norm) &
                ! & -resp(iz) &
                & -sum(stgas_ext(:,ispg)*rxnext(:,iz))*merge(dt,1d0,dt_norm) &
                & -rxngas(ispg,iz)*merge(dt,1d0,dt_norm) &
                & -mgassupp(ispg,iz)*merge(dt,1d0,dt_norm) &
                & ) &
                & *merge(0.0d0,1.0d0,mgasx(ispg,iz)<mgasth(ispg)*sw_red)
            
            
            if (iz/=nz) then 
                amx3(row,row+nsp3) = ( &
                        & -( 0.5d0*(dgas(ispg,iz)+dgas(ispg,iz+1))*(1d0)/(0.5d0*(dz(iz)+dz(min(nz,iz+1)))) &
                        & + 0.5d0*(ddgas_dmgas(ispg,ispg,iz+1))*(mgasx(ispg,iz+1)-mgasx(ispg,iz)) &
                        &       /(0.5d0*(dz(iz)+dz(min(nz,iz+1)))))/dz(iz)*merge(dt,1d0,dt_norm) &
                        & ) &
                        & *merge(0.0d0,mgasx(ispg,iz+1),mgasx(ispg,iz)<mgasth(ispg)*sw_red)
                
                do ispa = 1,nsp_aq
                    col = nsp3*(iz-1) + nsp_sld*solve_sld + ispa 
                    amx3(row,col+nsp3) = ( &
                        & -( 0.5d0*(ddgas_dmaq(ispg,ispa,iz+1))*(mgasx(ispg,iz+1)-mgasx(ispg,iz)) &
                        &       /(0.5d0*(dz(iz)+dz(min(nz,iz+1)))))/dz(iz)*merge(dt,1d0,dt_norm) &
                        & ) &
                        & *merge(0.0d0,maqx(ispa,iz+1),mgasx(ispg,iz)<mgasth(ispg)*sw_red)
                            
                enddo 
            
            endif 
            
            if (iz/=1) then 
                amx3(row,row-nsp3) = ( &
                    & -(- 0.5d0*(dgas(ispg,iz)+dgas(ispg,iz-1))*(-1d0)/(0.5d0*(dz(iz)+dz(max(1,iz-1)))) &
                    & - 0.5d0*(ddgas_dmgas(ispg,ispg,iz-1))*(mgasx(ispg,iz)-mgasx(ispg,iz-1)) &
                    &       /(0.5d0*(dz(iz)+dz(max(1,iz-1)))))/dz(iz)*merge(dt,1d0,dt_norm)  &
                    & +poro(iz)*sat(iz)*v(iz)*1d3*(-khgasx(ispg,iz-1)*1d0)/dz(iz)*merge(dt,1d0,dt_norm) &
                    & +poro(iz)*sat(iz)*v(iz)*1d3*(-dkhgas_dmgas(ispg,ispg,iz-1)*mgasx(ispg,iz-1))/dz(iz)*merge(dt,1d0,dt_norm) &
                    & ) &
                    & *merge(0.0d0,mgasx(ispg,iz-1),mgasx(ispg,iz)<mgasth(ispg)*sw_red)
                
                do ispa = 1,nsp_aq
                    col = nsp3*(iz-1) + nsp_sld*solve_sld + ispa 

                    amx3(row,col-nsp3) = ( &
                        & -(- 0.5d0*(ddgas_dmaq(ispg,ispa,iz-1))*(mgasx(ispg,iz)-mgasx(ispg,iz-1)) &
                        &       /(0.5d0*(dz(iz)+dz(max(1,iz-1)))))/dz(iz)*merge(dt,1d0,dt_norm)  &
                        & +poro(iz)*sat(iz)*v(iz)*1d3*(-dkhgas_dmaq(ispg,ispa,iz-1)*mgasx(ispg,iz-1))/dz(iz)*merge(dt,1d0,dt_norm) &
                        & ) &
                        & *merge(0.0d0,maqx(ispa,iz-1),mgasx(ispg,iz)<mgasth(ispg)*sw_red)
                            
                    if (row==2 .and. col==3) then
                        print*,row,col,'iz-1,dgas/daq'
                    endif 
                enddo 
            endif 
            
            if (.not.sld_enforce) then 
                do isps = 1,nsp_sld
                    col = nsp3*(iz-1) + isps 
                    amx3(row,col) = ( &
                        & -drxngas_dmsld(ispg,isps,iz)*merge(dt,1d0,dt_norm) &
                        & -sum(stgas_ext(:,ispg)*drxnext_dmsld(:,isps,iz))*merge(dt,1d0,dt_norm) &
                        & ) &
                        & *merge(1.0d0,msldx(isps,iz),mgasx(ispg,iz)<mgasth(ispg)*sw_red)
                enddo 
            endif 
            
            do ispa = 1, nsp_aq
                col = nsp3*(iz-1) + nsp_sld*solve_sld + ispa 
                amx3(row,col) = ( &
                    & (dagas_dmaq(ispg,ispa,iz)*mgasx(ispg,iz))/merge(1d0,dt,dt_norm) &
                    & -( 0.5d0*(ddgas_dmaq(ispg,ispa,iz))*(mgasx(ispg,min(nz,iz+1))-mgasx(ispg,iz)) &
                    &       /(0.5d0*(dz(iz)+dz(min(nz,iz+1)))) &
                    & - 0.5d0*(ddgas_dmaq(ispg,ispa,iz))*(mgasx(ispg,iz)-pco2n_tmp)/(0.5d0*(dz(iz)+dz(max(1,iz-1)))) )/dz(iz)  &
                    & *merge(dt,1d0,dt_norm) &
                    & +poro(iz)*sat(iz)*v(iz)*1d3*(dkhgas_dmaq(ispg,ispa,iz)*mgasx(ispg,iz))/dz(iz)*merge(dt,1d0,dt_norm) &
                    & -drxngas_dmaq(ispg,ispa,iz)*merge(dt,1d0,dt_norm) &
                    & -sum(stgas_ext(:,ispg)*drxnext_dmaq(:,ispa,iz))*merge(dt,1d0,dt_norm) &
                    & ) &
                    & *merge(1.0d0,maqx(ispa,iz),mgasx(ispg,iz)<mgasth(ispg)*sw_red)
                
            enddo 
            
            do ispg2 = 1, nsp_gas
                if (ispg == ispg2) cycle
                col = nsp3*(iz-1) + nsp_sld*solve_sld + nsp_aq + ispg2
                amx3(row,col) = ( &
                    & (dagas_dmgas(ispg,ispg2,iz)*mgasx(ispg,iz))/merge(1d0,dt,dt_norm) &
                    & -( 0.5d0*(ddgas_dmgas(ispg,ispg2,iz))*(mgasx(ispg,min(nz,iz+1))-mgasx(ispg,iz)) &
                    &       /(0.5d0*(dz(iz)+dz(min(nz,iz+1)))) &
                    & - 0.5d0*(ddgas_dmgas(ispg,ispg2,iz))*(mgasx(ispg,iz)-pco2n_tmp) &
                    &       /(0.5d0*(dz(iz)+dz(max(1,iz-1)))) )/dz(iz)*merge(dt,1d0,dt_norm)  &
                    & +poro(iz)*sat(iz)*v(iz)*1d3*(dkhgas_dmgas(ispg,ispg2,iz)*mgasx(ispg,iz))/dz(iz)*merge(dt,1d0,dt_norm) &
                    & -drxngas_dmgas(ispg,ispg2,iz)*merge(dt,1d0,dt_norm) &
                    & -sum(stgas_ext(:,ispg)*drxnext_dmgas(:,ispg2,iz))*merge(dt,1d0,dt_norm) &
                    & ) &
                    & *merge(1.0d0,mgasx(ispg2,iz),mgasx(ispg,iz)<mgasth(ispg)*sw_red)
                
            enddo 
            
            if (amx3(row,row)==0d0) then 
                print *,amx3(row,row),mgasx(ispg,iz)<mgasth(ispg)*sw_red,mgasx(ispg,iz) 
                print *, &
                & (agasx(ispg,iz) + dagas_dmgas(ispg,ispg,iz)*mgasx(ispg,iz)) &
                & ,-( 0.5d0*(dgas(ispg,iz)+dgas(ispg,min(nz,iz+1)))*merge(0d0,-1d0,iz==nz)/(0.5d0*(dz(iz)+dz(min(nz,iz+1)))) &
                & +0.5d0*(ddgas_dmgas(ispg,ispg,iz))*(mgasx(ispg,min(nz,iz+1))-mgasx(ispg,iz))/(0.5d0*(dz(iz)+dz(min(nz,iz+1)))) &
                & - 0.5d0*(dgas(ispg,iz)+edifn_tmp)*(1d0)/(0.5d0*(dz(iz)+dz(max(1,iz-1)))) &
                & - 0.5d0*(ddgas_dmgas(ispg,ispg,iz))*(mgasx(ispg,iz)-pco2n_tmp)/(0.5d0*(dz(iz)+dz(max(1,iz-1)))) )/dz(iz)  &
                & ,+poro(iz)*sat(iz)*v(iz)*1d3*(khgasx(ispg,iz)*1d0)/dz(iz) &
                & ,+poro(iz)*sat(iz)*v(iz)*1d3*(dkhgas_dmgas(ispg,ispg,iz)*mgasx(ispg,iz))/dz(iz) &
                & ,-sum(stgas_ext(:,ispg)*drxnext_dmgas(:,ispg,iz)) &
                & ,-drxngas_dmgas(ispg,ispg,iz) 
            endif 
            
            flx_gas(ispg,itflx,iz) = ( &
                & (agasx(ispg,iz)*mgasx(ispg,iz)-agas(ispg,iz)*mgas(ispg,iz))/dt &
                & )         
            flx_gas(ispg,idif,iz) = ( &
                & -( 0.5d0*(dgas(ispg,iz)+dgas(ispg,min(nz,iz+1)))*(mgasx(ispg,min(nz,iz+1))-mgasx(ispg,iz)) &
                &       /(0.5d0*(dz(iz)+dz(min(nz,iz+1)))) &
                & - 0.5d0*(dgas(ispg,iz)+edifn_tmp)*(mgasx(ispg,iz)-pco2n_tmp)/(0.5d0*(dz(iz)+dz(max(1,iz-1)))))/dz(iz)  &
                & )
            flx_gas(ispg,iadv,iz) = ( &
                & +poro(iz)*sat(iz)*v(iz)*1d3*(khgasx(ispg,iz)*mgasx(ispg,iz)-khco2n_tmp*pco2n_tmp)/dz(iz) &
                & )
            flx_gas(ispg,irxn_ext(:),iz) = -stgas_ext(:,ispg)*rxnext(:,iz)
            flx_gas(ispg,irain,iz) = - mgassupp(ispg,iz)
            flx_gas(ispg,irxn_sld(:),iz) = ( &
                ! & -stgas(:,ispg)*ksld(:,iz)*poro(iz)*hr(iz)*mv(:)*1d-6*msldx(:,iz)*(1d0-omega(:,iz)) &
                ! & *merge(0d0,1d0,1d0-omega(:,iz)*nonprec(:,iz) < 0d0)  &
                & - stgas(:,ispg)*rxnsld(:,iz) &
                & ) 
            flx_gas(ispg,ires,iz) = sum(flx_gas(ispg,:,iz))
            
            if (any(isnan(flx_gas(ispg,:,iz)))) then
                print *,flx_gas(ispg,:,iz)
            endif 
            
            ! amx3(row,:) = amx3(row,:)/alpha(iz)
            ! ymx3(row) = ymx3(row)/alpha(iz)
        enddo 

    end do 
    
    fact2= maxval(abs(amx3))
    
    amx3 = amx3/fact2
    ymx3 = ymx3/fact2
    
    ymx3=-1.0d0*ymx3

    if (any(isnan(amx3)).or.any(isnan(ymx3)).or.any(amx3>infinity).or.any(ymx3>infinity)) then 
    ! if (.true.) then 
        print*,'error in mtx'
        print*,'any(isnan(amx3)),any(isnan(ymx3))'
        print*,any(isnan(amx3)),any(isnan(ymx3))

        if (any(isnan(ymx3))) then 
            do ie = 1,nsp3*(nz)
                if (isnan(ymx3(ie))) then 
                    print*,'NAN is here...',ie
                endif
            enddo
        endif


        if (any(isnan(amx3))) then 
            do ie = 1,nsp3*(nz)
                do ie2 = 1,nsp3*(nz)
                    if (isnan(amx3(ie,ie2))) then 
                        print*,'NAN is here...',ie,ie2
                    endif
                enddo
            enddo
        endif
        
#ifdef errmtx_printout
        open(unit=11,file='amx.txt',status = 'replace')
        open(unit=12,file='ymx.txt',status = 'replace')
        do ie = 1,nsp3*(nz)
            write(11,*) (amx3(ie,ie2),ie2 = 1,nsp3*nz)
            write(12,*) ymx3(ie)
        enddo 
        close(11)
        close(12) 
#endif 
        
        flgback = .true.
        ! pause
        exit

        stop
    endif

    call DGESV(nsp3*(Nz),int(1),amx3,nsp3*(Nz),IPIV3,ymx3,nsp3*(Nz),INFO) 

    if (any(isnan(ymx3))) then
        print*,'error in soultion'
        
#ifdef errmtx_printout
        open(unit=11,file='amx.txt',status = 'replace')
        open(unit=12,file='ymx.txt',status = 'replace')
        do ie = 1,nsp3*(nz)
            write(11,*) (amx3(ie,ie2),ie2 = 1,nsp3*nz)
            write(12,*) ymx3(ie)
        enddo 
        close(11)
        close(12)   
#endif     
        
        flgback = .true.
        ! pause
        exit
        
        
    endif

    do iz = 1, nz
        if (.not.sld_enforce) then 
            do isps = 1, nsp_sld
                row = isps + nsp3*(iz-1)

                if (isnan(ymx3(row))) then 
                    print *,'nan at', iz,z(iz),chrsld(isps)
                    stop
                endif
                
                ! emx3(row) = (1d0-poro(iz))*msldx(isps,iz)*exp(ymx3(row)) -(1d0-poro(iz))*msldx(isps,iz)
                emx3(row) = msldx(isps,iz)*exp(ymx3(row)) - msldx(isps,iz)

                if ((.not.isnan(ymx3(row))).and.ymx3(row) >threshold) then 
                    msldx(isps,iz) = msldx(isps,iz)*corr
                else if (ymx3(row) < -threshold) then 
                    msldx(isps,iz) = msldx(isps,iz)/corr
                else   
                    msldx(isps,iz) = msldx(isps,iz)*exp(ymx3(row))
                endif
                
                if ( msldx(isps,iz)<msldth(isps)) then ! too small trancate value and not be accounted for error 
                    msldx(isps,iz)=msldth(isps)
                    ymx3(row) = 0d0
                endif
            enddo 
        endif 
        
        do ispa = 1, nsp_aq
            row = ispa + nsp_sld*solve_sld + nsp3*(iz-1)

            if (isnan(ymx3(row))) then 
                print *,'nan at', iz,z(iz),chraq(ispa)
                stop
            endif
            
            emx3(row) = poro(iz)*sat(iz)*1d3*maqx(ispa,iz)*exp(ymx3(row)) - poro(iz)*sat(iz)*1d3*maqx(ispa,iz)

            if ((.not.isnan(ymx3(row))).and.ymx3(row) >threshold) then 
                maqx(ispa,iz) = maqx(ispa,iz)*corr
            else if (ymx3(row) < -threshold) then 
                maqx(ispa,iz) = maqx(ispa,iz)/corr
            else   
                maqx(ispa,iz) = maqx(ispa,iz)*exp(ymx3(row))
            endif
            
            if (maqx(ispa,iz)<maqth(ispa)) then ! too small trancate value and not be accounted for error 
                maqx(ispa,iz)=maqth(ispa)
                ymx3(row) = 0d0
            endif
        enddo 
        
        do ispg = 1, nsp_gas
            row = ispg + nsp_aq + nsp_sld*solve_sld + nsp3*(iz-1)

            if (isnan(ymx3(row))) then 
                print *,'nan at', iz,z(iz),chrgas(ispg)
                stop
            endif
            
            emx3(row) =agasx(ispg,iz)* mgasx(ispg,iz)*exp(ymx3(row)) - agasx(ispg,iz)*mgasx(ispg,iz) 

            if ((.not.isnan(ymx3(row))).and.ymx3(row) >threshold) then 
                mgasx(ispg,iz) = mgasx(ispg,iz)*corr
            else if (ymx3(row) < -threshold) then 
                mgasx(ispg,iz) = mgasx(ispg,iz)/corr
            else   
                mgasx(ispg,iz) = mgasx(ispg,iz)*exp(ymx3(row))
            endif
            
            if (mgasx(ispg,iz)<mgasth(ispg)) then ! too small trancate value and not be accounted for error 
                mgasx(ispg,iz)=mgasth(ispg)
                ymx3(row) = 0d0
            endif
        enddo 
        
#ifdef calcw_full
        row =  nsp3*(iz-1) + nsp3
        if (isnan(ymx3(row))) then 
            print *,'nan at', iz,z(iz),'w'
            stop
        endif
        
        emx3(row) = w(iz)*exp(ymx3(row)) - w(iz) 
        emx3(row) = abs(ymx3(row))  
        
        w(iz) = w(iz) + ymx3(row)
        
        ! if ((.not.isnan(ymx3(row))).and.ymx3(row) >threshold) then 
            ! w(iz) = w(iz)*corr
        ! else if (ymx3(row) < -threshold) then 
            ! w(iz) = w(iz)/corr
        ! else   
            ! w(iz) = w(iz)*exp(ymx3(row))
        ! endif
        
        ! if (mgasx(ispg,iz)<mgasth(ispg)) then ! too small trancate value and not be accounted for error 
            ! mgasx(ispg,iz)=mgasth(ispg)
            ! ymx3(row) = 0d0
        ! endif
#endif 

    end do 

    if (fact_tol == 1d0) then 
        error = maxval(exp(abs(ymx3))) - 1.0d0
    else 
        error = maxval((abs(emx3)))
    endif 
    
    if (isnan(error)) error = 1d4

    if (isnan(error).or.info/=0 .or. any(isnan(msldx)) .or. any(isnan(maqx)).or. any(isnan(mgasx))) then 
        error = 1d3
        print *, '!! error is NaN; values are returned to those before iteration with reducing dt'
        print*, 'isnan(error), info/=0,any(isnan(msldx)),any(isnan(maqx)),any(isnan(mgasx))'
        print*,isnan(error),info,any(isnan(msldx)),any(isnan(maqx)),any(isnan(mgasx))
        
#ifdef errmtx_printout
        open(unit=11,file='amx.txt',status = 'replace')
        open(unit=12,file='ymx.txt',status = 'replace')
        do ie = 1,nsp3*(nz)
            write(11,*) (amx3(ie,ie2),ie2 = 1,nsp3*nz)
            write(12,*) ymx3(ie)
        enddo 
        close(11)
        close(12)         
#endif 
        
        ! dt = dt/10d0
        flgback = .true.
        ! pause
        exit
        
        
        ! stop
    endif

    if (display) then 
        print '(a,E11.3,a,i0,a,E11.3)', 'iteration error = ',error, ', iteration = ',iter,', time step [yr] = ',dt
    endif      
    iter = iter + 1 

    if (iter > iter_Max ) then
    ! if (iter > iter_Max .or. (method_precalc .and. error > infinity)) then
        ! dt = dt/1.01d0
        ! dt = dt/10d0
        if (dt==0d0) then 
            print *, 'dt==0d0; stop'
        
#ifdef errmtx_printout
            open(unit=11,file='amx.txt',status = 'replace')
            open(unit=12,file='ymx.txt',status = 'replace')
            do ie = 1,nsp3*(nz)
                write(11,*) (amx3(ie,ie2),ie2 = 1,nsp3*nz)
                write(12,*) ymx3(ie)
            enddo 
            close(11)
            close(12)      
#endif 
            stop
        endif 
        flgback = .true.
        
        exit 
    end if
    
#ifdef dispiter
        write(chrfmt,'(i0)') nz_disp
        chrfmt = '(a5,'//trim(adjustl(chrfmt))//'(1x,E11.3))'
        
        print *
        print *,' [concs] '
        print trim(adjustl(chrfmt)),'z',(z(iz),iz=1,nz,nz/nz_disp)
        if (nsp_aq>0) then 
            print *,' < aq species >'
            do ispa = 1, nsp_aq
                print trim(adjustl(chrfmt)), trim(adjustl(chraq(ispa))), (maqx(ispa,iz),iz=1,nz, nz/nz_disp)
            enddo 
        endif 
        if (nsp_sld>0) then 
            print *,' < sld species >'
            do isps = 1, nsp_sld
                print trim(adjustl(chrfmt)), trim(adjustl(chrsld(isps))), (msldx(isps,iz),iz=1,nz, nz/nz_disp)
            enddo 
        endif 
        if (nsp_gas>0) then 
            print *,' < gas species >'
            do ispg = 1, nsp_gas
                print trim(adjustl(chrfmt)), trim(adjustl(chrgas(ispg))), (mgasx(ispg,iz),iz=1,nz, nz/nz_disp)
            enddo 
        endif 
        print *
#endif     

enddo

! just addint flx calculation at the end 

    
flx_sld = 0d0
flx_aq = 0d0
flx_gas = 0d0

flx_co2sp = 0d0

! pH calculation and its derivative wrt aq and gas species


call calc_pH_v7_3( &
    & nz,kw,nsp_aq,nsp_gas,nsp_aq_all,nsp_gas_all,nsp_aq_cnst,nsp_gas_cnst &! input 
    & ,chraq,chraq_cnst,chraq_all,chrgas,chrgas_cnst,chrgas_all &!input
    & ,maqx,maqc,mgasx,mgasc,keqgas_h,keqaq_h,keqaq_c,keqaq_s,maqth_all,keqaq_no3,keqaq_nh3 &! input
    & ,print_cb,print_loc,z &! input 
    & ,dprodmaq_all,dprodmgas_all,dso4fdmaq_all,dso4fdmgas_all &! output
    & ,prox,ph_error,so4f,ph_iter &! output
    & ) 
    
! recalculation of rate constants for mineral reactions

if (kin_iter) then 

    ksld = 0d0
        
    call get_mgasx_all( &
        & nz,nsp_gas_all,nsp_gas,nsp_gas_cnst &
        & ,chrgas,chrgas_all,chrgas_cnst &
        & ,mgasx,mgasc &
        & ,mgasx_loc  &! output
        & )

    do isps =1,nsp_sld 
        call sld_kin( &
            & nz,rg,tc,sec2yr,tempk_0,prox,poro,hr,kw,kho,mv(isps) &! input
            & ,nsp_gas_all,chrgas_all,mgasx_loc &! input
            & ,chrsld(isps),'pro  ' &! input 
            & ,kin,dkin_dmsp &! output
            & ) 
        ksld(isps,:) = kin
    enddo 

endif 
    
! if kin const. is specified in input file 
if (nsld_kinspc > 0) then 
    do isps_kinspc=1,nsld_kinspc    
        if ( any( chrsld == chrsld_kinspc(isps_kinspc))) then 
            select case (trim(adjustl(chrsld_kinspc(isps_kinspc))))
                case('g1','g2','g3') ! for OMs, turn over year needs to be provided [yr]
                    ksld(findloc(chrsld,chrsld_kinspc(isps_kinspc),dim=1),:) = ( &                   
                        & 1d0/kin_sld_spc(isps_kinspc) &
                        & ) 
                    dksld_dpro(findloc(chrsld,chrsld_kinspc(isps_kinspc),dim=1),:) = 0d0
                    dksld_dso4f(findloc(chrsld,chrsld_kinspc(isps_kinspc),dim=1),:) = 0d0
                    dksld_dmaq(findloc(chrsld,chrsld_kinspc(isps_kinspc),dim=1),:,:) = 0d0
                    dksld_dmgas(findloc(chrsld,chrsld_kinspc(isps_kinspc),dim=1),:,:) = 0d0
                case default ! otherwise, usual rate constant [mol/m2/yr]
                    ksld(findloc(chrsld,chrsld_kinspc(isps_kinspc),dim=1),:) = ( &                            
                        & kin_sld_spc(isps_kinspc) &
                        & ) 
                    dksld_dpro(findloc(chrsld,chrsld_kinspc(isps_kinspc),dim=1),:) = 0d0
                    dksld_dso4f(findloc(chrsld,chrsld_kinspc(isps_kinspc),dim=1),:) = 0d0
                    dksld_dmaq(findloc(chrsld,chrsld_kinspc(isps_kinspc),dim=1),:,:) = 0d0
                    dksld_dmgas(findloc(chrsld,chrsld_kinspc(isps_kinspc),dim=1),:,:) = 0d0
            end select 
        endif 
    enddo 
endif 

! saturation state calc. and their derivatives wrt aq and gas species

omega = 0d0

do isps =1, nsp_sld
    ! dummy = 0d0
    ! dummy2 = 0d0
    ! call calc_omega_dev_v2( &
        ! & nz,nsp_aq,nsp_gas,nsp_aq_all,nsp_sld_all,nsp_gas_all,nsp_aq_cnst,nsp_gas_cnst &! input 
        ! & ,chraq,chraq_cnst,chraq_all,chrsld_all,chrgas,chrgas_cnst,chrgas_all &!input
        ! & ,maqx,maqc,mgasx,mgasc,keqgas_h,keqaq_h,keqaq_c,keqsld_all,mgasth_all,keqaq_s,so4f,staq_all &! input
        ! & ,prox,chrsld(isps),'pro  ' &! input 
        ! & ,dummy,dummy2,omega_error &! output
        ! & )
    ! if (omega_error) then
        ! flgback = .true.
        ! exit 
    ! endif 
    ! omega(isps,:) = dummy
    dummy = 0d0
    call calc_omega_v4( &
        & nz,nsp_aq,nsp_gas,nsp_aq_all,nsp_sld_all,nsp_gas_all,nsp_aq_cnst,nsp_gas_cnst & 
        & ,chraq,chraq_cnst,chraq_all,chrsld_all,chrgas,chrgas_cnst,chrgas_all &
        & ,maqx,maqc,mgasx,mgasc,mgasth_all,prox,so4f &
        & ,keqsld_all,keqgas_h,keqaq_h,keqaq_c,keqaq_s,keqaq_no3 &
        & ,staq_all,stgas_all &
        & ,chrsld(isps) &
        & ,domega_dmaq_all,domega_dmgas_all,domega_dpro_loc,domega_dso4f_loc &! output
        & ,dummy,omega_error &! output
        & )
    omega(isps,:) = dummy
enddo 

rxnsld = 0d0
    
call sld_rxn( &
    & nz,nsp_sld,nsp_aq,nsp_gas,msld_seed,hr,poro,mv,ksld,omega,nonprec,msldx,dz &! input 
    & ,dksld_dmaq,domega_dmaq,dksld_dmgas,domega_dmgas,precstyle &! input
    & ,msld,msldth,dt,sat,maq,maqth,agas,mgas,mgasth,staq,stgas &! input
    & ,rxnsld,drxnsld_dmsld,drxnsld_dmaq,drxnsld_dmgas &! output
    & ) 

! adding reactions that are not based on dis/prec of minerals
rxnext = 0d0

do irxn=1,nrxn_ext
    dummy = 0d0
    dummy2 = 0d0
    call calc_rxn_ext_dev_2( &
        & nz,nrxn_ext_all,nsp_gas_all,nsp_aq_all,nsp_gas,nsp_aq,nsp_aq_cnst,nsp_gas_cnst  &!input
        & ,chrrxn_ext_all,chrgas,chrgas_all,chrgas_cnst,chraq,chraq_all,chraq_cnst &! input
        & ,poro,sat,maqx,maqc,mgasx,mgasc,mgasth_all,maqth_all,krxn1_ext_all,krxn2_ext_all &! input
        & ,nsp_sld,nsp_sld_cnst,chrsld,chrsld_cnst,msldx,msldc,rho_grain,kw &!input
        & ,rg,tempk_0,tc &!input
        & ,nsp_sld_all,chrsld_all,msldth_all,mv_all,hr,prox,keqgas_h,keqaq_h,keqaq_c,keqaq_s,so4f &! input
        & ,chrrxn_ext(irxn),'pro  ' &! input 
        & ,dummy,dummy2,rxnext_error &! output
        & )
    if (rxnext_error) then
        flgback = .true.
        exit 
    endif 
    rxnext(irxn,:) = dummy
enddo 

if (.not.sld_enforce)then 
    do iz = 1, nz  !================================
        
        do isps = 1, nsp_sld
            
            k_tmp = ksld(isps,iz)
            mv_tmp = mv(isps)
            omega_tmp = omega(isps,iz)
            omega_tmp_th = omega_tmp*nonprec(isps,iz)
            m_tmp = msldx(isps,iz)
            mth_tmp = msldth(isps) 
            mi_tmp = msldi(isps)
            mp_tmp = msldx(isps,min(nz,iz+1))
            msupp_tmp = msldsupp(isps,iz)
            rxn_ext_tmp = sum(stsld_ext(:,isps)*rxnext(:,iz))
            mprev_tmp = msld(isps,iz)
            w_tmp = w(iz)
            wp_tmp = w(min(nz,iz+1))
            sporo_tmp = 1d0-poro(iz)
            sporop_tmp = 1d0-poro(min(nz,iz+1)) 
            sporoprev_tmp = 1d0-poroprev(iz)
            mn_tmp = msldx(isps,max(1,iz-1))
            wn_tmp = w(max(1,iz-1))
            sporon_tmp = 1d0-poro(max(1,iz-1))
            
            if (iz==1) then 
                mn_tmp = 0d0
                wn_tmp = 0d0
                sporon_tmp = 0d0
            endif 
            
            if (iz==nz) then 
                mp_tmp = mi_tmp
                wp_tmp = w_btm
                sporop_tmp = 1d0- poroi
            endif 
            
            if (msldunit == 'blk') then 
                sporo_tmp = 1d0
                sporop_tmp = 1d0
                sporon_tmp = 1d0
                sporoprev_tmp = 1d0
            endif 
            
            ! diffusion terms are filled with transition matrices 
            ! if (turbo2(isps).or.labs(isps)) then
                ! do iiz = 1, nz
                    ! if (trans(iiz,iz,isps)==0d0) cycle
                        
                    ! flx_sld(isps,idif,iz) = flx_sld(isps,idif,iz) + ( &
                        ! & - trans(iiz,iz,isps)/dz(iz)*dz(iiz)*msldx(isps,iiz) &
                        ! & )
                ! enddo
            ! else
                ! do iiz = 1, nz
                    ! if (trans(iiz,iz,isps)==0d0) cycle
                        
                    ! flx_sld(isps,idif,iz) = flx_sld(isps,idif,iz) + ( &
                        ! & - trans(iiz,iz,isps)/dz(iz)*msldx(isps,iiz) &
                        ! & )
                ! enddo
            ! endif
            
            do iiz = 1, nz
                if (trans(iiz,iz,isps)==0d0) cycle
                    
                flx_sld(isps,idif,iz) = flx_sld(isps,idif,iz) + ( &
                    & - trans(iiz,iz,isps)*msldx(isps,iiz) * sporo(iiz) &
                    & )
            enddo
            
            flx_sld(isps,itflx,iz) = ( &
                & (sporo_tmp*m_tmp - sporoprev_tmp*mprev_tmp)/dt &
                & )
            flx_sld(isps,iadv,iz) = ( &
                & - ( sporop_tmp*wp_tmp*mp_tmp - sporo_tmp*w_tmp* m_tmp)/dz(iz)  &
                ! & - adf(iz)*up(iz)*( sporop_tmp*wp_tmp*mp_tmp - sporo_tmp*w_tmp* m_tmp)/dz(iz)  &
                ! & - adf(iz)*dwn(iz)*( sporo_tmp*w_tmp* m_tmp - sporon_tmp*wn_tmp*mn_tmp )/dz(iz)  &
                ! & - adf(iz)*cnr(iz)*( sporop_tmp*wp_tmp*mp_tmp - sporon_tmp*wn_tmp*mn_tmp )/dz(iz)  &
                & )
            ! flx_sld(isps,irxn_sld(isps),iz) = ( &
                ! & + k_tmp*poro(iz)*hr(iz)*mv_tmp*1d-6*m_tmp*(1d0-omega_tmp) &
                ! & *merge(0d0,1d0,1d0-omega_tmp_th < 0d0) &
                ! & )
            flx_sld(isps,irxn_sld(isps),iz) = ( &
                & + rxnsld(isps,iz) &
                & )
            flx_sld(isps,irain,iz) = (&
                & - msupp_tmp  &
                & )
            flx_sld(isps,irxn_ext(:),iz) = (&
                    & - stsld_ext(:,isps)*rxnext(:,iz)  &
                    & )
            flx_sld(isps,ires,iz) = sum(flx_sld(isps,:,iz))
            if (isnan(flx_sld(isps,ires,iz))) then 
                print *,chrsld(isps),iz,(flx_sld(isps,iflx,iz),iflx=1,nflx)
            endif   
            
        enddo 
    end do  !================================
endif 

do iz = 1, nz
    
    do ispa = 1, nsp_aq
        
        d_tmp = daq(ispa)
        caq_tmp = maqx(ispa,iz)
        caq_tmp_prev = maq(ispa,iz)
        caq_tmp_p = maqx(ispa,min(nz,iz+1))
        caq_tmp_n = maqx(ispa,max(1,iz-1))
        caqth_tmp = maqth(ispa)
        caqi_tmp = maqi(ispa)
        caqsupp_tmp = maqsupp(ispa,iz)
        rxn_ext_tmp = sum(staq_ext(:,ispa)*rxnext(:,iz))
        rxn_tmp = sum(staq(:,ispa)*rxnsld(:,iz))
        
        if (iz==1) caq_tmp_n = caqi_tmp
            
        edif_tmp = 1d3*poro(iz)*sat(iz)*tora(iz)*d_tmp
        edif_tmp_p = 1d3*poro(min(iz+1,nz))*sat(min(iz+1,nz))*tora(min(iz+1,nz))*d_tmp
        edif_tmp_n = 1d3*poro(max(iz-1,1))*sat(max(iz-1,1))*tora(max(iz-1,1))*d_tmp
                
        flx_aq(ispa,itflx,iz) = (&
            & (poro(iz)*sat(iz)*1d3*caq_tmp-poroprev(iz)*sat(iz)*1d3*caq_tmp_prev)/dt  &
            & ) 
        flx_aq(ispa,iadv,iz) = (&
            & + poro(iz)*sat(iz)*1d3*v(iz)*(caq_tmp-caq_tmp_n)/dz(iz) &
            & ) 
        flx_aq(ispa,idif,iz) = (&
            & -(0.5d0*(edif_tmp +edif_tmp_p)*(caq_tmp_p-caq_tmp)/(0.5d0*(dz(iz)+dz(min(nz,iz+1)))) &
            & -0.5d0*(edif_tmp +edif_tmp_n)*(caq_tmp-caq_tmp_n)/(0.5d0*(dz(iz)+dz(max(1,iz-1)))))/dz(iz) &
            & ) 
        flx_aq(ispa,irxn_sld(:),iz) = (& 
            ! & -staq(:,ispa)*ksld(:,iz)*poro(iz)*hr(iz)*mv(:)*1d-6*msldx(:,iz)*(1d0-omega(:,iz)) &
            ! & *merge(0d0,1d0,1d0-omega(:,iz)*nonprec(:,iz) < 0d0) &
            & - staq(:,ispa)*rxnsld(:,iz) &
            & ) 
        flx_aq(ispa,irain,iz) = (&
            & - caqsupp_tmp &
            & ) 
        flx_aq(ispa,irxn_ext(:),iz) = (&
            & - staq_ext(:,ispa)*rxnext(:,iz) &
            & ) 
        flx_aq(ispa,ires,iz) = sum(flx_aq(ispa,:,iz))
        if (isnan(flx_aq(ispa,ires,iz))) then 
            print *,chraq(ispa),iz,(flx_aq(ispa,iflx,iz),iflx=1,nflx)
        endif 
    
    enddo 
    
end do  ! ==============================

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!    pCO2 & pO2   !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

khgas = 0d0
khgasx = 0d0
! added
if (new_gassol) then 
    call calc_khgas_all( &
        & nz,nsp_aq_all,nsp_gas_all,nsp_gas,nsp_aq,nsp_aq_cnst,nsp_gas_cnst &
        & ,chraq_all,chrgas_all,chraq_cnst,chrgas_cnst,chraq,chrgas &
        & ,maq,mgas,maqx,mgasx,maqc,mgasc &
        & ,keqgas_h,keqaq_h,keqaq_c,keqaq_s,keqaq_no3  &
        & ,pro,prox,so4fprev,so4f &
        & ,khgas_all,khgasx_all,dkhgas_dpro_all,dkhgas_dso4f_all,dkhgas_dmaq_all,dkhgas_dmgas_all &!output
        & )
        
    do ispg=1,nsp_gas
        khgas(ispg,:)=khgas_all(findloc(chrgas_all,chrgas(ispg),dim=1),:)
        khgasx(ispg,:)=khgasx_all(findloc(chrgas_all,chrgas(ispg),dim=1),:)
    enddo 
endif 

dgas = 0d0

agas = 0d0
agasx = 0d0

rxngas = 0d0

do ispg = 1, nsp_gas
    
    if (.not.new_gassol) then ! to be removed?
        select case (trim(adjustl(chrgas(ispg))))
            case('pco2')
                khgas(ispg,:) = kco2*(1d0+k1/pro + k1*k2/pro/pro) ! previous value; should not change through iterations 
                khgasx(ispg,:) = kco2*(1d0+k1/prox + k1*k2/prox/prox)
            case('po2')
                khgas(ispg,:) = kho ! previous value; should not change through iterations 
                khgasx(ispg,:) = kho
            case('pnh3')
                khgas(ispg,:) = knh3*(1d0+pro/k1nh3) ! previous value; should not change through iterations 
                khgasx(ispg,:) = knh3*(1d0+prox/k1nh3)
            case('pn2o')
                khgas(ispg,:) = kn2o ! previous value; should not change through iterations 
                khgasx(ispg,:) = kn2o
        endselect 
    endif 
    
    dgas(ispg,:) = ucv*poro*(1.0d0-sat)*1d3*torg*dgasg(ispg)+poro*sat*khgasx(ispg,:)*1d3*tora*dgasa(ispg)
    dgasi(ispg) = ucv*1d3*dgasg(ispg) 
    
    agas(ispg,:)= ucv*poroprev*(1.0d0-sat)*1d3+poroprev*sat*khgas(ispg,:)*1d3
    agasx(ispg,:)= ucv*poro*(1.0d0-sat)*1d3+poro*sat*khgasx(ispg,:)*1d3
    
    do isps = 1, nsp_sld
        rxngas(ispg,:) =  rxngas(ispg,:) + (&
            ! & stgas(isps,ispg)*ksld(isps,:)*poro*hr*mv(isps)*1d-6*msldx(isps,:)*(1d0-omega(isps,:)) &
            ! & *merge(0d0,1d0,1d0-omega(isps,:)*nonprec(isps,:) < 0d0) &
            & + stgas(isps,ispg)*rxnsld(isps,:) &
            & )
    enddo 
enddo 

! print *,drxngas_dmaq(findloc(chrgas,'pco2',dim=1),findloc(chraq,'ca',dim=1),:)

do iz = 1, nz
    
    do ispg = 1, nsp_gas
        
        pco2n_tmp = mgasx(ispg,max(1,iz-1))
        khco2n_tmp = khgasx(ispg,max(1,iz-1))
        edifn_tmp = dgas(ispg,max(1,iz-1))
        if (iz == 1) then 
            pco2n_tmp = mgasi(ispg)
            khco2n_tmp = khgasi(ispg)
            edifn_tmp = dgasi(ispg)
        endif 
        
        flx_gas(ispg,itflx,iz) = ( &
            & (agasx(ispg,iz)*mgasx(ispg,iz)-agas(ispg,iz)*mgas(ispg,iz))/dt &
            & )         
        flx_gas(ispg,idif,iz) = ( &
            & -( 0.5d0*(dgas(ispg,iz)+dgas(ispg,min(nz,iz+1)))*(mgasx(ispg,min(nz,iz+1))-mgasx(ispg,iz)) &
            &       /(0.5d0*(dz(iz)+dz(min(nz,iz+1)))) &
            & - 0.5d0*(dgas(ispg,iz)+edifn_tmp)*(mgasx(ispg,iz)-pco2n_tmp)/(0.5d0*(dz(iz)+dz(max(1,iz-1)))))/dz(iz)  &
            & )
        flx_gas(ispg,iadv,iz) = ( &
            & +poro(iz)*sat(iz)*v(iz)*1d3*(khgasx(ispg,iz)*mgasx(ispg,iz)-khco2n_tmp*pco2n_tmp)/dz(iz) &
            & )
        flx_gas(ispg,irxn_ext(:),iz) = -stgas_ext(:,ispg)*rxnext(:,iz)
        flx_gas(ispg,irain,iz) = - mgassupp(ispg,iz)
        flx_gas(ispg,irxn_sld(:),iz) = ( &
            ! & -stgas(:,ispg)*ksld(:,iz)*poro(iz)*hr(iz)*mv(:)*1d-6*msldx(:,iz)*(1d0-omega(:,iz)) &
            ! & *merge(0d0,1d0,1d0-omega(:,iz)*nonprec(:,iz) < 0d0) &
            & - stgas(:,ispg)*rxnsld(:,iz) &
            & )
        flx_gas(ispg,ires,iz) = sum(flx_gas(ispg,:,iz))
        
        if (any(isnan(flx_gas(ispg,:,iz)))) then
            print *,flx_gas(ispg,:,iz)
        endif 
    enddo 
    
    if (any(chrgas=='pco2')) then 
        ispg = findloc(chrgas,'pco2',dim=1)
        
        pco2n_tmp = mgasx(ispg,max(1,iz-1))
        proi_tmp = prox(max(1,iz-1))
        if (iz == 1) then 
            pco2n_tmp = mgasi(ispg)
            proi_tmp = proi
        endif 
        
        ! gaseous CO2
        
        edifn_tmp = ucv*poro(max(1,iz-1))*(1.0d0-sat(max(1,iz-1)))*1d3*torg(max(1,iz-1))*dgasg(ispg)
        if (iz==1) edifn_tmp = dgasi(ispg)
        
        flx_co2sp(1,itflx,iz) = ( &
            & (ucv*poro(iz)*(1.0d0-sat(Iz))*1d3*mgasx(ispg,iz)-ucv*poroprev(iz)*(1.0d0-sat(Iz))*1d3*mgas(ispg,iz))/dt &
            & )  
        flx_co2sp(1,idif,iz) = ( &
            & -( 0.5d0*(ucv*poro(iz)*(1.0d0-sat(iz))*1d3*torg(Iz)*dgasg(ispg) &
            &       +ucv*poro(min(nz,iz+1))*(1.0d0-sat(min(nz,iz+1)))*1d3*torg(min(nz,iz+1))*dgasg(ispg)) &
            &       *(mgasx(ispg,min(nz,iz+1))-mgasx(ispg,iz)) &
            &       /(0.5d0*(dz(iz)+dz(min(nz,iz+1)))) &
            & - 0.5d0*(ucv*poro(iz)*(1.0d0-sat(iz))*1d3*torg(Iz)*dgasg(ispg) + edifn_tmp) &
            &       *(mgasx(ispg,iz)-pco2n_tmp)/(0.5d0*(dz(iz)+dz(max(1,iz-1)))))/dz(iz)  &
            & ) 
        flx_co2sp(1,irxn_ext(:),iz) = -stgas_ext(:,ispg)*rxnext(:,iz)
        flx_co2sp(1,irain,iz) = - mgassupp(ispg,iz)
        flx_co2sp(1,irxn_sld(:),iz) = ( &
            & - stgas(:,ispg)*rxnsld(:,iz) &
            & )
            
        ! dissolved CO2
        
        edifn_tmp = poro(max(1,iz-1))*sat(max(1,iz-1))*kco2*1d3*tora(max(1,iz-1))*dgasa(ispg)
        if (iz==1) edifn_tmp = 0d0
        
        flx_co2sp(2,itflx,iz) = ( &
            & (poro(iz)*sat(iz)*kco2*1d3*mgasx(ispg,iz)-poroprev(iz)*sat(iz)*kco2*1d3*mgas(ispg,iz))/dt &
            & )  
        flx_co2sp(2,idif,iz) = ( &
            & -( 0.5d0*(poro(iz)*sat(iz)*kco2*1d3*tora(iz)*dgasa(ispg) &
            &       +poro(min(nz,iz+1))*sat(min(nz,iz+1))*kco2*1d3*tora(min(nz,iz+1))*dgasa(ispg)) &
            &       *(mgasx(ispg,min(nz,iz+1))-mgasx(ispg,iz)) &
            &       /(0.5d0*(dz(iz)+dz(min(nz,iz+1)))) &
            & - 0.5d0*(poro(iz)*sat(iz)*kco2*1d3*tora(iz)*dgasa(ispg) + edifn_tmp) &
            &       *(mgasx(ispg,iz)-pco2n_tmp)/(0.5d0*(dz(iz)+dz(max(1,iz-1)))))/dz(iz)  &
            & ) 
        flx_co2sp(2,iadv,iz) = ( &
            & +poro(iz)*sat(iz)*v(iz)*1d3*(kco2*mgasx(ispg,iz)- kco2*pco2n_tmp)/dz(iz) &
            & )
            
        ! HCO3-
        
        edifn_tmp = poro(max(1,iz-1))*sat(max(1,iz-1))*kco2*k1/prox(max(1,iz-1))*1d3*tora(max(1,iz-1))*dgasa(ispg)
        if (iz==1) edifn_tmp = 0d0
        
        flx_co2sp(3,itflx,iz) = ( &
            & (poro(iz)*sat(iz)*kco2*k1/prox(iz)*1d3*mgasx(ispg,iz)-poroprev(iz)*sat(iz)*kco2*k1/pro(iz)*1d3*mgas(ispg,iz))/dt &
            & )  
        flx_co2sp(3,idif,iz) = ( &
            & -( 0.5d0*(poro(iz)*sat(iz)*kco2*k1/prox(iz)*1d3*tora(iz)*dgasa(ispg) &
            &       +poro(min(nz,iz+1))*sat(min(nz,iz+1))*kco2*k1/prox(min(nz,iz+1))*1d3*tora(min(nz,iz+1))*dgasa(ispg)) &
            &       *(mgasx(ispg,min(nz,iz+1))-mgasx(ispg,iz)) &
            &       /(0.5d0*(dz(iz)+dz(min(nz,iz+1)))) &
            & - 0.5d0*(poro(iz)*sat(iz)*kco2*k1/prox(iz)*1d3*tora(iz)*dgasa(ispg) + edifn_tmp) &
            &       *(mgasx(ispg,iz)-pco2n_tmp)/(0.5d0*(dz(iz)+dz(max(1,iz-1)))))/dz(iz)  &
            & ) 
        flx_co2sp(3,iadv,iz) = ( &
            & +poro(iz)*sat(iz)*v(iz)*1d3*( &
            &       kco2*k1/prox(iz)*mgasx(ispg,iz) &
            &       - kco2*k1/proi_tmp*pco2n_tmp)/dz(iz) &
            & )
            
        ! CO32-
        
        edifn_tmp = poro(max(1,iz-1))*sat(max(1,iz-1))*kco2*k1*k2/prox(max(1,iz-1))**2d0*1d3*tora(max(1,iz-1))*dgasa(ispg)
        if (iz==1) edifn_tmp = 0d0
        
        flx_co2sp(4,itflx,iz) = (  &
            & (poro(iz)*sat(iz)*kco2*k1*k2/prox(iz)**2d0*1d3*mgasx(ispg,iz) &
            &       -poroprev(iz)*sat(iz)*kco2*k1*k2/pro(iz)**2d0*1d3*mgas(ispg,iz))/dt &
            & )  
        flx_co2sp(4,idif,iz) = ( &
            & -( 0.5d0*(poro(iz)*sat(iz)*kco2*k1*k2/prox(iz)**2d0*1d3*tora(iz)*dgasa(ispg) &
            &       +poro(min(nz,iz+1))*sat(min(nz,iz+1))*kco2*k1*k2/prox(min(nz,iz+1))**2d0*1d3*tora(min(nz,iz+1))*dgasa(ispg)) &
            &       *(mgasx(ispg,min(nz,iz+1))-mgasx(ispg,iz)) &
            &       /(0.5d0*(dz(iz)+dz(min(nz,iz+1)))) &
            & - 0.5d0*(poro(iz)*sat(iz)*kco2*k1*k2/prox(iz)**2d0*1d3*tora(iz)*dgasa(ispg) + edifn_tmp) &
            &       *(mgasx(ispg,iz)-pco2n_tmp)/(0.5d0*(dz(iz)+dz(max(1,iz-1)))))/dz(iz)  &
            & ) 
        flx_co2sp(4,iadv,iz) = ( &
            & +poro(iz)*sat(iz)*v(iz)*1d3*( &
            &       kco2*k1*k2/prox(iz)**2d0*mgasx(ispg,iz) &
            &       - kco2*k1*k2/proi_tmp**2d0*pco2n_tmp)/dz(iz) &
            & )
            
            
        flx_co2sp(1,ires,iz) = sum(flx_co2sp(:,1:nflx-1,iz))
        flx_co2sp(2,ires,iz) = sum(flx_co2sp(:,1:nflx-1,iz))
        flx_co2sp(3,ires,iz) = sum(flx_co2sp(:,1:nflx-1,iz))
        flx_co2sp(4,ires,iz) = sum(flx_co2sp(:,1:nflx-1,iz))
    endif 
    
end do 

    
#ifdef dispiter
        
print *
print *,' [saturation & pH] '
if (nsp_sld>0) then 
    print *,' < sld species omega >'
    do isps = 1, nsp_sld
        print trim(adjustl(chrfmt)), trim(adjustl(chrsld(isps))), (omega(isps,iz),iz=1,nz, nz/nz_disp)
    enddo 
endif 
print *,' < pH >'
print trim(adjustl(chrfmt)), 'ph', (-log10(prox(iz)),iz=1,nz, nz/nz_disp)
print *

write(chrfmt,'(i0)') nflx
chrfmt = '(a5,'//trim(adjustl(chrfmt))//'(1x,a11))'

print *
print *,' [fluxes] '
print trim(adjustl(chrfmt)),'time',(chrflx(iflx),iflx=1,nflx)

write(chrfmt,'(i0)') nflx
chrfmt = '(a5,'//trim(adjustl(chrfmt))//'(1x,E11.3))'
if (nsp_aq>0) then 
    print *,' < aq species >'
    do ispa = 1, nsp_aq
        print trim(adjustl(chrfmt)), trim(adjustl(chraq(ispa))), (sum(flx_aq(ispa,iflx,:)*dz(:)),iflx=1,nflx)
    enddo 
endif 
if (nsp_sld>0) then 
    print *,' < sld species >'
    do isps = 1, nsp_sld
        print trim(adjustl(chrfmt)), trim(adjustl(chrsld(isps))), (sum(flx_sld(isps,iflx,:)*dz(:)),iflx=1,nflx)
    enddo 
endif 
if (nsp_gas>0) then 
    print *,' < gas species >'
    do ispg = 1, nsp_gas
        print trim(adjustl(chrfmt)), trim(adjustl(chrgas(ispg))), (sum(flx_gas(ispg,iflx,:)*dz(:)),iflx=1,nflx)
    enddo 
endif 
print *
#endif     

if (chkflx .and. dt > dt_th) then 
    flx_max_max = 0d0
    do isps = 1, nsp_sld

        flx_max = 0d0
        do iflx = 1, nflx
            flx_max = max(flx_max,abs(sum(flx_sld(isps,iflx,:)*dz)))
        enddo 
        
        flx_max_max = max(flx_max_max,flx_max)
    enddo 

    do ispa = 1, nsp_aq

        flx_max = 0d0
        do iflx = 1, nflx
            flx_max = max(flx_max,abs(sum(flx_aq(ispa,iflx,:)*dz)))
        enddo 
        flx_max_max = max(flx_max_max,flx_max)
    enddo 

    do ispg = 1, nsp_gas

        flx_max = 0d0
        do iflx = 1, nflx
            flx_max = max(flx_max,abs(sum(flx_gas(ispg,iflx,:)*dz)))
        enddo 
        flx_max_max = max(flx_max_max,flx_max)
    enddo 
    
    if (.not.sld_enforce) then 
        do isps = 1, nsp_sld

            flx_max = 0d0
            do iflx = 1, nflx
                flx_max = max(flx_max,abs(sum(flx_sld(isps,iflx,:)*dz)))
            enddo 
            
            if (flx_max/flx_max_max > flx_max_tol .and.  abs(sum(flx_sld(isps,ires,:)*dz))/flx_max > flx_tol ) then 
                print *, 'too large error in mass balance of sld phases'
                print *,'sp | flx that raised the flag | flx_max  | flx_tol'
                print *,chrsld(isps),abs(sum(flx_sld(isps,ires,:)*dz)),flx_max,flx_tol
                ! pause
                flgback = .true.
                return
            
                open(unit=11,file='amx.txt',status = 'replace')
                open(unit=12,file='ymx.txt',status = 'replace')
                do ie = 1,nsp3*(nz)
                    write(11,*) (amx3(ie,ie2),ie2 = 1,nsp3*nz)
                    write(12,*) ymx3(ie)
                enddo 
                close(11)
                close(12)     
                
                stop
                ! dt = dt/10d0
            endif 
        enddo 
    endif 

    do ispa = 1, nsp_aq

        flx_max = 0d0
        do iflx = 1, nflx
            flx_max = max(flx_max,abs(sum(flx_aq(ispa,iflx,:)*dz)))
        enddo 
        
        if (flx_max/flx_max_max > flx_max_tol  .and. abs(sum(flx_aq(ispa,ires,:)*dz))/flx_max > flx_tol ) then 
            print *, 'too large error in mass balance of aq phases'
            print *,'sp | flx that raised the flag | flx_max  | flx_tol' 
            print *,chraq(ispa),abs(sum(flx_aq(ispa,ires,:)*dz)),flx_max,flx_tol
            ! pause
            flgback = .true.
            return
        
            open(unit=11,file='amx.txt',status = 'replace')
            open(unit=12,file='ymx.txt',status = 'replace')
            do ie = 1,nsp3*(nz)
                write(11,*) (amx3(ie,ie2),ie2 = 1,nsp3*nz)
                write(12,*) ymx3(ie)
            enddo 
            close(11)
            close(12)     
            
            stop
            ! dt = dt/10d0
        endif 
    enddo 

    do ispg = 1, nsp_gas

        flx_max = 0d0
        do iflx = 1, nflx
            flx_max = max(flx_max,abs(sum(flx_gas(ispg,iflx,:)*dz)))
        enddo 
        
        if (flx_max/flx_max_max > flx_max_tol  .and. abs(sum(flx_gas(ispg,ires,:)*dz))/flx_max > flx_tol ) then 
            print *, 'too large error in mass balance of gas phases'
            print *,'sp | flx that raised the flag | flx_max  | flx_tol' 
            print *,chrgas(ispg),abs(sum(flx_gas(ispg,ires,:)*dz)),flx_max,flx_tol
            ! pause
            flgback = .true.
            return
        
            open(unit=11,file='amx.txt',status = 'replace')
            open(unit=12,file='ymx.txt',status = 'replace')
            do ie = 1,nsp3*(nz)
                write(11,*) (amx3(ie,ie2),ie2 = 1,nsp3*nz)
                write(12,*) ymx3(ie)
            enddo 
            close(11)
            close(12)     
            
            ! dt = dt/10d0
            stop
        endif 
    enddo 
endif 

endsubroutine alsilicate_aq_gas_1D_v3_1

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine sld_rxn( &
    & nz,nsp_sld,nsp_aq,nsp_gas,msld_seed,hr,poro,mv,ksld,omega,nonprec,msldx,dz &! input 
    & ,dksld_dmaq,domega_dmaq,dksld_dmgas,domega_dmgas,precstyle &! input
    & ,msld,msldth,dt,sat,maq,maqth,agas,mgas,mgasth,staq,stgas &! input
    & ,rxnsld,drxnsld_dmsld,drxnsld_dmaq,drxnsld_dmgas &! output
    & ) 
implicit none 

integer,intent(in)::nz,nsp_sld,nsp_aq,nsp_gas
real(kind=8),intent(in)::msld_seed,dt
real(kind=8),dimension(nz),intent(in)::hr,poro,sat,dz
real(kind=8),dimension(nsp_sld),intent(in)::mv,msldth
real(kind=8),dimension(nsp_sld,nsp_aq),intent(in)::staq
real(kind=8),dimension(nsp_sld,nsp_gas),intent(in)::stgas
real(kind=8),dimension(nsp_aq),intent(in)::maqth
real(kind=8),dimension(nsp_aq,nz),intent(in)::maq
real(kind=8),dimension(nsp_gas),intent(in)::mgasth
real(kind=8),dimension(nsp_gas,nz),intent(in)::mgas,agas
real(kind=8),dimension(nsp_sld,nz),intent(in)::ksld,omega,nonprec,msldx,msld
real(kind=8),dimension(nsp_sld,nsp_aq,nz),intent(in)::dksld_dmaq,domega_dmaq
real(kind=8),dimension(nsp_sld,nsp_gas,nz),intent(in)::dksld_dmgas,domega_dmgas
character(10),dimension(nsp_sld),intent(in)::precstyle
real(kind=8),dimension(nsp_sld,nz),intent(out)::rxnsld,drxnsld_dmsld
real(kind=8),dimension(nsp_sld,nsp_aq,nz),intent(out)::drxnsld_dmaq
real(kind=8),dimension(nsp_sld,nsp_gas,nz),intent(out)::drxnsld_dmgas

integer ispa,isps,ispg,iz
real(kind=8),dimension(nsp_sld,nz)::maxdis,maxprec

real(kind=8)::auth_th = 1d2
    
rxnsld = 0d0
drxnsld_dmsld = 0d0
drxnsld_dmaq = 0d0
drxnsld_dmgas = 0d0

maxdis = 1d200
maxprec = -1d200
do isps=1,nsp_sld
    maxdis(isps,:) = min(maxdis(isps,:),(msld(isps,:)-msldth(isps))/dt)
    do ispa = 1,nsp_aq
        if (staq(isps,ispa)<0d0) then 
            maxdis(isps,:) = min(maxdis(isps,:), -1d0/staq(isps,ispa)*poro*sat*1d3*(maq(ispa,:)-maqth(ispa))/dt )
        endif 
    enddo 
    do ispg = 1,nsp_gas
        if (stgas(isps,ispg)<0d0) then 
            maxdis(isps,:) = min(maxdis(isps,:), -1d0/stgas(isps,ispg)*agas(ispg,:)*(mgas(ispg,:)-mgasth(ispg))/dt )
        endif 
    enddo 
    do ispa = 1,nsp_aq
        if (staq(isps,ispa)>0d0) then 
            maxprec(isps,:) = max(maxprec(isps,:), -1d0/staq(isps,ispa)*poro*sat*1d3*(maq(ispa,:)-maqth(ispa))/dt )
        endif 
    enddo 
    do ispg = 1,nsp_gas
        if (stgas(isps,ispg)>0d0) then 
            maxprec(isps,:) = max(maxprec(isps,:), -1d0/stgas(isps,ispg)*agas(ispg,:)*(mgas(ispg,:)-mgasth(ispg))/dt )
        endif 
    enddo 
enddo 

do isps = 1,nsp_sld
    select case(trim(adjustl(precstyle(isps))))
    
        case ('full_lim') 
            
            do iz = 1,nz
                if (1d0-omega(isps,iz) > 0d0) then 
                    rxnsld(isps,iz) = ksld(isps,iz)*poro(iz)*hr(iz)*mv(isps)*1d-6*msldx(isps,iz)*(1d0-omega(isps,iz)) 
                    if (rxnsld(isps,iz)> maxdis(isps,iz)) then 
                        rxnsld(isps,iz) = maxdis(isps,iz)
                        drxnsld_dmsld(isps,iz) = 0d0
                        drxnsld_dmaq(isps,:,iz) = 0d0
                        drxnsld_dmgas(isps,:,iz) = 0d0
                    else 
                        drxnsld_dmsld(isps,iz) = ksld(isps,iz)*poro(iz)*hr(iz)*mv(isps)*1d-6*1d0*(1d0-omega(isps,iz)) 
                        drxnsld_dmaq(isps,:,iz) = ( &
                            & +ksld(isps,iz)*poro(iz)*hr(iz)*mv(isps)*1d-6*msldx(isps,iz)*(-domega_dmaq(isps,:,iz)) &
                            & +dksld_dmaq(isps,:,iz)*poro(iz)*hr(iz)*mv(isps)*1d-6*msldx(isps,iz)*(1d0-omega(isps,iz)) &
                            & )
                        drxnsld_dmgas(isps,:,iz) = ( &
                            & +ksld(isps,iz)*poro(iz)*hr(iz)*mv(isps)*1d-6*msldx(isps,iz)*(-domega_dmgas(isps,:,iz)) &
                            & +dksld_dmgas(isps,:,iz)*poro(iz)*hr(iz)*mv(isps)*1d-6*msldx(isps,iz)*(1d0-omega(isps,iz)) &
                            & )
                    endif 
                elseif (1d0-omega(isps,iz) < 0d0) then 
                    if (nonprec(isps,iz)==1d0) then 
                        rxnsld(isps,iz) = 0d0
                        drxnsld_dmsld(isps,iz) = 0d0
                        drxnsld_dmaq(isps,:,iz) = 0d0
                        drxnsld_dmgas(isps,:,iz) = 0d0
                    elseif (nonprec(isps,iz)==0d0) then 
                        rxnsld(isps,iz) = ksld(isps,iz)*poro(iz)*hr(iz)*(1d0-omega(isps,iz))
                        if (rxnsld(isps,iz) < maxprec(isps,iz)) then 
                            rxnsld(isps,iz) = maxprec(isps,iz)
                            drxnsld_dmsld(isps,iz) = 0d0
                            drxnsld_dmaq(isps,:,iz) = 0d0
                            drxnsld_dmgas(isps,:,iz) = 0d0
                        else
                            rxnsld(isps,iz) = ksld(isps,iz)*poro(iz)*hr(iz)*(1d0-omega(isps,iz))
                            drxnsld_dmsld(isps,iz) = 0d0
                            drxnsld_dmaq(isps,:,iz) = ( &
                                & +ksld(isps,iz)*poro(iz)*hr(iz)*(-domega_dmaq(isps,:,iz)) &
                                & +dksld_dmaq(isps,:,iz)*poro(iz)*hr(iz)*(1d0-omega(isps,iz)) &
                                & )
                            drxnsld_dmgas(isps,:,iz) = ( &
                                & +ksld(isps,iz)*poro(iz)*hr(iz)*(-domega_dmgas(isps,:,iz)) &
                                & +dksld_dmgas(isps,:,iz)*poro(iz)*hr(iz)*(1d0-omega(isps,iz)) &
                                & )
                        endif 
                    endif 
                endif 
            enddo 
            
    
        case ('full') 
            rxnsld(isps,:) = ( &
                & + min(ksld(isps,:)*poro*hr*mv(isps)*1d-6*msldx(isps,:)*(1d0-omega(isps,:))/(1d0-poro),maxdis(isps,:)) &
                & *merge(0d0,1d0,1d0-omega(isps,:) < 0d0) &
                &  + max(ksld(isps,:)*poro*hr*(1d0-omega(isps,:)),maxprec(isps,:)) &
                & *merge(0d0,1d0,1d0-omega(isps,:)*(1d0-nonprec(isps,:)) > 0d0) &
                & )
            
            drxnsld_dmsld(isps,:) = ( &
                & + ksld(isps,:)*poro*hr*mv(isps)*1d-6*1d0*(1d0-omega(isps,:)) &
                & *merge(0d0,1d0,1d0-omega(isps,:) < 0d0) &
                & )
                
            do ispa = 1,nsp_aq
                drxnsld_dmaq(isps,ispa,:) = ( &
                    & + ksld(isps,:)*poro*hr*mv(isps)*1d-6*msldx(isps,:)*(-domega_dmaq(isps,ispa,:)) &
                    & *merge(0d0,1d0,1d0-omega(isps,:) < 0d0) &
                    & + dksld_dmaq(isps,ispa,:)*poro*hr*mv(isps)*1d-6*msldx(isps,:)*(1d0-omega(isps,:)) &
                    & *merge(0d0,1d0,1d0-omega(isps,:) < 0d0) &
                    &  + ksld(isps,:)*poro*hr*(-domega_dmaq(isps,ispa,:)) &
                    & *merge(0d0,1d0,1d0-omega(isps,:)*(1d0-nonprec(isps,:)) > 0d0) &
                    &  + dksld_dmaq(isps,ispa,:)*poro*hr*(1d0-omega(isps,:)) &
                    & *merge(0d0,1d0,1d0-omega(isps,:)*(1d0-nonprec(isps,:)) > 0d0) &
                    & )
            enddo 
                
            do ispg = 1,nsp_gas
                drxnsld_dmgas(isps,ispg,:) = ( &
                    & + ksld(isps,:)*poro*hr*mv(isps)*1d-6*msldx(isps,:)*(-domega_dmgas(isps,ispg,:)) &
                    & *merge(0d0,1d0,1d0-omega(isps,:) < 0d0) &
                    & /(1d0-poro) &
                    & + dksld_dmgas(isps,ispg,:)*poro*hr*mv(isps)*1d-6*msldx(isps,:)*(1d0-omega(isps,:)) &
                    & *merge(0d0,1d0,1d0-omega(isps,:) < 0d0) &
                    & /(1d0-poro) &
                    &  + ksld(isps,:)*poro*hr*(-domega_dmgas(isps,ispg,:)) &
                    & *merge(0d0,1d0,1d0-omega(isps,:)*(1d0-nonprec(isps,:)) > 0d0) &
                    &  + dksld_dmgas(isps,ispg,:)*poro*hr*(1d0-omega(isps,:)) &
                    & *merge(0d0,1d0,1d0-omega(isps,:)*(1d0-nonprec(isps,:)) > 0d0) &
                    & )
            enddo 
            
            
        case('seed')
            rxnsld(isps,:) = ( &
                & + ksld(isps,:)*poro*hr*mv(isps)*1d-6*(msldx(isps,:)+msld_seed)*(1d0-omega(isps,:)) &
                & *merge(0d0,1d0,1d0-omega(isps,:)*nonprec(isps,:) < 0d0) &
                & )
        
            drxnsld_dmsld(isps,:) = ( &
                & + ksld(isps,:)*poro*hr*mv(isps)*1d-6*1d0*(1d0-omega(isps,:)) &
                & *merge(0d0,1d0,1d0-omega(isps,:)*nonprec(isps,:) < 0d0) &
                & )
            
            do ispa = 1, nsp_aq
                drxnsld_dmaq(isps,ispa,:) = ( &
                    & + ksld(isps,:)*poro*hr*mv(isps)*1d-6*(msldx(isps,:)+msld_seed)*(-domega_dmaq(isps,ispa,:)) &
                    & *merge(0d0,1d0,1d0-omega(isps,:)*nonprec(isps,:) < 0d0) &
                    & + dksld_dmaq(isps,ispa,:)*poro*hr*mv(isps)*1d-6*(msldx(isps,:)+msld_seed)*(1d0-omega(isps,:)) &
                    & *merge(0d0,1d0,1d0-omega(isps,:)*nonprec(isps,:) < 0d0) &
                    & )
            enddo 
            
            do ispg = 1, nsp_gas
                drxnsld_dmgas(isps,ispg,:) = ( &
                    & + ksld(isps,:)*poro*hr*mv(isps)*1d-6*(msldx(isps,:)+msld_seed)*(-domega_dmgas(isps,ispg,:)) &
                    & *merge(0d0,1d0,1d0-omega(isps,:)*nonprec(isps,:) < 0d0) &
                    & + dksld_dmgas(isps,ispg,:)*poro*hr*mv(isps)*1d-6*(msldx(isps,:)+msld_seed)*(1d0-omega(isps,:)) &
                    & *merge(0d0,1d0,1d0-omega(isps,:)*nonprec(isps,:) < 0d0) &
                    & )
            enddo 
        
        
        case('decay')
            rxnsld(isps,:) = ( &
                & + ksld(isps,:)*msldx(isps,:)*(1d0-omega(isps,:)) &
                & *merge(0d0,1d0,1d0-omega(isps,:)*nonprec(isps,:) < 0d0) &
                & )
        
            drxnsld_dmsld(isps,:) = ( &
                & + ksld(isps,:)*1d0*(1d0-omega(isps,:)) &
                & *merge(0d0,1d0,1d0-omega(isps,:)*nonprec(isps,:) < 0d0) &
                & )
            
            do ispa = 1, nsp_aq
                drxnsld_dmaq(isps,ispa,:) = ( &
                    & + ksld(isps,:)*msldx(isps,:)*(-domega_dmaq(isps,ispa,:)) &
                    & *merge(0d0,1d0,1d0-omega(isps,:)*nonprec(isps,:) < 0d0) &
                    & + dksld_dmaq(isps,ispa,:)*msldx(isps,:)*(1d0-omega(isps,:)) &
                    & *merge(0d0,1d0,1d0-omega(isps,:)*nonprec(isps,:) < 0d0) &
                    & )
            enddo 
            
            do ispg = 1, nsp_gas
                drxnsld_dmgas(isps,ispg,:) = ( &
                    & + ksld(isps,:)*msldx(isps,:)*(-domega_dmgas(isps,ispg,:)) &
                    & *merge(0d0,1d0,1d0-omega(isps,:)*nonprec(isps,:) < 0d0) &
                    & + dksld_dmgas(isps,ispg,:)*msldx(isps,:)*(1d0-omega(isps,:)) &
                    & *merge(0d0,1d0,1d0-omega(isps,:)*nonprec(isps,:) < 0d0) &
                    & )
            enddo 
        
        
        case('2/3noporo')
            rxnsld(isps,:) = ( &
                & + ksld(isps,:)*hr*(mv(isps)*1d-6*msldx(isps,:))**(2d0/3d0)*(1d0-omega(isps,:)) &
                & *merge(0d0,1d0,1d0-omega(isps,:)*nonprec(isps,:) < 0d0) &
                & )
        
            drxnsld_dmsld(isps,:) = ( &
                & + ksld(isps,:)*hr*(mv(isps)*1d-6)**(2d0/3d0) &
                &       *(2d0/3d0)*msldx(isps,:)**(-1d0/3d0)*(1d0-omega(isps,:)) &
                & *merge(0d0,1d0,1d0-omega(isps,:)*nonprec(isps,:) < 0d0) &
                & )
            
            do ispa = 1, nsp_aq
                drxnsld_dmaq(isps,ispa,:) = ( &
                    & + ksld(isps,:)*hr*(mv(isps)*1d-6*msldx(isps,:))**(2d0/3d0)*(-domega_dmaq(isps,ispa,:)) &
                    & *merge(0d0,1d0,1d0-omega(isps,:)*nonprec(isps,:) < 0d0) &
                    & + dksld_dmaq(isps,ispa,:)*hr*(mv(isps)*1d-6*msldx(isps,:))**(2d0/3d0)*(1d0-omega(isps,:)) &
                    & *merge(0d0,1d0,1d0-omega(isps,:)*nonprec(isps,:) < 0d0) &
                    & )
            enddo 
            
            do ispg = 1, nsp_gas
                drxnsld_dmgas(isps,ispg,:) = ( &
                    & + ksld(isps,:)*hr*(mv(isps)*1d-6*msldx(isps,:))**(2d0/3d0)*(-domega_dmgas(isps,ispg,:)) &
                    & *merge(0d0,1d0,1d0-omega(isps,:)*nonprec(isps,:) < 0d0) &
                    & + dksld_dmgas(isps,ispg,:)*hr*(mv(isps)*1d-6*msldx(isps,:))**(2d0/3d0)*(1d0-omega(isps,:)) &
                    & *merge(0d0,1d0,1d0-omega(isps,:)*nonprec(isps,:) < 0d0) &
                    & )
            enddo 
        
        
        case('2/3')
            rxnsld(isps,:) = ( &
                & + ksld(isps,:)*poro**(2d0/3d0)*hr*(mv(isps)*1d-6*msldx(isps,:))**(2d0/3d0)*(1d0-omega(isps,:)) &
                & *merge(0d0,1d0,1d0-omega(isps,:)*nonprec(isps,:) < 0d0) &
                & )
        
            drxnsld_dmsld(isps,:) = ( &
                & + ksld(isps,:)*poro**(2d0/3d0)*hr*(mv(isps)*1d-6)**(2d0/3d0) &
                &       *(2d0/3d0)*msldx(isps,:)**(-1d0/3d0)*(1d0-omega(isps,:)) &
                & *merge(0d0,1d0,1d0-omega(isps,:)*nonprec(isps,:) < 0d0) &
                & )
            
            do ispa = 1, nsp_aq
                drxnsld_dmaq(isps,ispa,:) = ( &
                    & + ksld(isps,:)*poro**(2d0/3d0)*hr*(mv(isps)*1d-6*msldx(isps,:))**(2d0/3d0)*(-domega_dmaq(isps,ispa,:)) &
                    & *merge(0d0,1d0,1d0-omega(isps,:)*nonprec(isps,:) < 0d0) &
                    & + dksld_dmaq(isps,ispa,:)*poro**(2d0/3d0)*hr*(mv(isps)*1d-6*msldx(isps,:))**(2d0/3d0)*(1d0-omega(isps,:)) &
                    & *merge(0d0,1d0,1d0-omega(isps,:)*nonprec(isps,:) < 0d0) &
                    & )
            enddo 
            
            do ispg = 1, nsp_gas
                drxnsld_dmgas(isps,ispg,:) = ( &
                    & + ksld(isps,:)*poro**(2d0/3d0)*hr*(mv(isps)*1d-6*msldx(isps,:))**(2d0/3d0)*(-domega_dmgas(isps,ispg,:)) &
                    & *merge(0d0,1d0,1d0-omega(isps,:)*nonprec(isps,:) < 0d0) &
                    & + dksld_dmgas(isps,ispg,:)*poro**(2d0/3d0)*hr*(mv(isps)*1d-6*msldx(isps,:))**(2d0/3d0)*(1d0-omega(isps,:)) &
                    & *merge(0d0,1d0,1d0-omega(isps,:)*nonprec(isps,:) < 0d0) &
                    & )
            enddo 
        
        
        case default
            rxnsld(isps,:) = ( &
                & + ksld(isps,:)*poro*hr*mv(isps)*1d-6*msldx(isps,:)*(1d0-omega(isps,:)) &
                & *merge(0d0,1d0,1d0-omega(isps,:)*nonprec(isps,:) < 0d0) &
                & )
        
            drxnsld_dmsld(isps,:) = ( &
                & + ksld(isps,:)*poro*hr*mv(isps)*1d-6*1d0*(1d0-omega(isps,:)) &
                & *merge(0d0,1d0,1d0-omega(isps,:)*nonprec(isps,:) < 0d0) &
                & )
            
            do ispa = 1, nsp_aq
                drxnsld_dmaq(isps,ispa,:) = ( &
                    & + ksld(isps,:)*poro*hr*mv(isps)*1d-6*msldx(isps,:)*(-domega_dmaq(isps,ispa,:)) &
                    & *merge(0d0,1d0,1d0-omega(isps,:)*nonprec(isps,:) < 0d0) &
                    & + dksld_dmaq(isps,ispa,:)*poro*hr*mv(isps)*1d-6*msldx(isps,:)*(1d0-omega(isps,:)) &
                    & *merge(0d0,1d0,1d0-omega(isps,:)*nonprec(isps,:) < 0d0) &
                    & )
            enddo 
            
            do ispg = 1, nsp_gas
                drxnsld_dmgas(isps,ispg,:) = ( &
                    & + ksld(isps,:)*poro*hr*mv(isps)*1d-6*msldx(isps,:)*(-domega_dmgas(isps,ispg,:)) &
                    & *merge(0d0,1d0,1d0-omega(isps,:)*nonprec(isps,:) < 0d0) &
                    & + dksld_dmgas(isps,ispg,:)*poro*hr*mv(isps)*1d-6*msldx(isps,:)*(1d0-omega(isps,:)) &
                    & *merge(0d0,1d0,1d0-omega(isps,:)*nonprec(isps,:) < 0d0) &
                    & )
            enddo 
            
            ! correcting for solid fraction available to porewater 
            
            ! rxnsld(isps,:) = rxnsld(isps,:)/(1d0-poro)
            ! drxnsld_dmsld(isps,:) = drxnsld_dmsld(isps,:)/(1d0-poro)
            ! drxnsld_dmaq(isps,:,:) = drxnsld_dmaq(isps,:,:)/(1d0-poro)
            ! drxnsld_dmgas(isps,:,:) = drxnsld_dmgas(isps,:,:)/(1d0-poro)
            
            
            ! attempt to add authigenesis above some threshould for omega
            ! do iz=1,nz 
                ! if (nonprec(isps,iz)==0d0 .and. omega(isps,iz) > auth_th) then 
                    ! rxnsld(isps,iz) = rxnsld(isps,iz) + ( &
                        ! & + ksld(isps,iz)*poro(iz)*hr(iz)*(1d0-omega(isps,iz)) &
                        ! & )
                    
                    ! do ispa = 1, nsp_aq
                        ! drxnsld_dmaq(isps,ispa,iz) = drxnsld_dmaq(isps,ispa,iz) + ( &
                            ! & + ksld(isps,iz)*poro(iz)*hr(iz)*(-domega_dmaq(isps,ispa,iz)) &
                            ! & + dksld_dmaq(isps,ispa,iz)*poro(iz)*hr(iz)*(1d0-omega(isps,iz)) &
                            ! & )
                    ! enddo 
                    
                    ! do ispg = 1, nsp_gas
                        ! drxnsld_dmgas(isps,ispg,iz) = drxnsld_dmgas(isps,ispg,iz) + ( &
                            ! & + ksld(isps,iz)*poro(iz)*hr(iz)*(-domega_dmgas(isps,ispg,iz)) &
                            ! & + dksld_dmgas(isps,ispg,iz)*poro(iz)*hr(iz)*(1d0-omega(isps,iz)) &
                            ! & )
                    ! enddo 
                ! endif 
            ! enddo 
            
            ! print *, 'max-rxnflx', isps, sum (ksld(isps,:)*poro*hr*mv(isps)*1d-6*msldx(isps,:)*dz)
    
    endselect
enddo   
   
endsubroutine sld_rxn

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine psd_diss( &
    & nsp_sld,nps,nflx &! in
    & ,z,flx_sld,mv,dt,pi,tol,poro &! in 
    & ,incld_rough,rough_c0,rough_c1 &! in
    & ,profdir,ipsd &! in
    & ,ps,dps,ps_min,ps_max &! in 
    & ,psd,dpsd,psd_error_flg &! inout
    & )
implicit none 

integer,intent(in)::nsp_sld,nps,nflx,ipsd
real(kind=8),intent(in)::dt,ps_min,ps_max,pi,tol,rough_c0,rough_c1 
real(kind=8),dimension(nz),intent(in)::z,poro
real(kind=8),dimension(nsp_sld,nflx,nz),intent(in)::flx_sld
real(kind=8),dimension(nsp_sld),intent(in)::mv
real(kind=8),dimension(nps),intent(in)::ps,dps
logical,intent(in)::incld_rough
character(256),intent(in)::profdir
real(kind=8),dimension(nps,nz),intent(inout)::psd,dpsd
logical,intent(inout)::psd_error_flg
! local 
real(kind=8),dimension(nps,nz)::dVd,psd_old,psd_new,dpsd_tmp
real(kind=8),dimension(nps)::psd_tmp,dvd_tmp
real(kind=8),dimension(nz)::DV
real(kind=8) ps_new,ps_newp,dvd_res
integer ips,iips,ips_new,iz,isps
logical :: safe_mode = .false.
! logical :: safe_mode = .true.

! attempt to do psd ( defined with particle number / bulk m3 / log (r) )
! assumptions: 
! 1. particle numbers are only affected by transport (including raining/dusting) 
! 2. dissolution does not change particle numbers: it only affect particle distribution 
! unless particle is the minimum radius. in this case particle can be lost via dissolution 
! 3. when a mineral precipitates, it is assumed to increase particle radius?
! e.g., when a 1 um of particle is dissolved by X m3, its radius is changed and this particle is put into a different bin of (smaller) radius 

! sum of volume change of minerals at iz is DV = sum(flx_sld(5:5+nsp_sld,iz)*mv(:)*1d-6)*dt (m3 / m3) 
! this must be distributed to different particle size bins (dV(r)) in proportion to psd * (4*pi*r^2)
! dV(r) = DV/(psd*4*pi*r^2) where dV is m3 / bulk m3 / log(r) 
! has to modify so that sum( dV * dps ) = DV 
! new psd is obtained by dV(r) = psd(r)*( 4/3 * pi * r^3 - 4/3 * pi * r'^3 ) where r' is the new radius as a result of dissolution
! if r' is exactly one of ps value (ps(ips) == r'), then  psd(r') = psd(r)
! else: 
! first find the closest r* value which is one of ps values.
! then DV(r) = psd(r)* 4/3 * pi * r^3 - psd(r*)* 4/3 * pi * r*^3 
! i.e., psd(r*) = [ psd(r)* 4/3 * pi * r^3 - DV(r)]  /( 4/3 * pi * r*^3)
!               = [ psd(r)* 4/3 * pi * r^3 - psd(r)*( 4/3 * pi * r^3 - 4/3 * pi * r'^3 ) ] /( 4/3 * pi * r*^3)
!               = psd(r) * 4/3 * pi * r'^3 /( 4/3 * pi * r*^3)
!               = psd(r) * (r'/r*)^3
! in this way volume is conservative? 
! check: sum( psd(r) * 4/3 * pi * r^3 * dps) - sum( psd(r') * 4/3 * pi * r'^3 * dps) = DV 

dpsd_tmp = 0d0
psd_old = psd
psd_new = psd
do iz=1,nz

    DV(iz) = 0d0
    do isps = 1,nsp_sld 
        ! DV(iz) = DV(iz) + flx_sld(isps, 4 + isps,iz)*mv(isps)*1d-6*dt/(1d0 - poro(iz))  
        DV(iz) = DV(iz) + flx_sld(isps, 4 + isps,iz)*mv(isps)*1d-6*dt  
    enddo 
    ! the following should be removed
    do ips = 1, nps
        if ( psd (ips,iz) /= 0d0 ) then 
            dVd(ips,iz) = DV(iz)/ ( psd (ips,iz) * (10d0**ps(ips))**2d0 )
        else 
            dVd(ips,iz) = 0d0
        endif 
    enddo 
    
    ! correct one?
    dVd = 0d0
    if (.not.incld_rough) then 
        dVd(:,iz) = ( psd (:,iz) * (10d0**ps(:))**2d0 )
    else
        dVd(:,iz) = ( psd (:,iz) * (10d0**ps(:))**2d0 *rough_c0*(10d0**ps(:))**rough_c1)
    endif 
    
    if (all(dVd == 0d0)) then 
        print *,'all dissolved loc1?'
        psd_error_flg = .true.
        return
        stop
    endif 
    
    ! scale with DV
    dVd(:,iz) = dVd(:,iz)*DV(iz)/sum(dVd(:,iz) * dps(:))
    
    if ( abs( (sum(dVd(:,iz) * dps(:)) - DV(iz))/DV(iz)) > tol ) then
        print *, ' vol. balance failed somehow ',abs( (sum(dVd(:,iz) * dps(:)) - DV(iz))/DV(iz))
        print *, iz, sum(dVd(:,iz) * dps(:)), DV(iz)
        stop
    endif 
    
    if (any(isnan(dVd(:,iz))) ) then 
        print *, 'nan in dVd loc 1'
        stop
    endif 
    
    do ips = 1, nps
        
        if ( psd(ips,iz) == 0d0) cycle
        
        if ( ips == 1 .and. dVd(ips,iz) > 0d0 ) then 
            ! this is the minimum size dealt within the model 
            ! so if dissolved (dVd > 0), particle number must reduce 
            ! (revised particle volumes) = (initial particle volumes) - (volume change) 
            ! psd'(ips,iz) * 4d0/3d0*pi*(10d0**ps(ips))**3d0 =  psd(ips,iz) * 4d0/3d0*pi*(10d0**ps(ips))**3d0 - dVd(ips,iz) 
            ! [ psd'(ips,iz) - psd(ips,iz) ] * 4d0/3d0*pi*(10d0**ps(ips))**3d0 = - dVd(ips,iz) 
            if ( .not. safe_mode ) then  ! do not care about producing negative particle number
                dpsd_tmp(ips,iz) = dpsd_tmp(ips,iz) - dVd(ips,iz)/(4d0/3d0*pi*(10d0**ps(ips))**3d0) 
            elseif ( safe_mode ) then   ! never producing negative particle number
                if ( dVd(ips,iz)/(4d0/3d0*pi*(10d0**ps(ips))**3d0) < psd(ips,iz) ) then ! when dissolution does not consume existing particles 
                    dpsd_tmp(ips,iz) = dpsd_tmp(ips,iz) - dVd(ips,iz)/(4d0/3d0*pi*(10d0**ps(ips))**3d0) 
                else ! when dissolution exceeds potential consumption of existing particles 
                    ! dvd_res is defined as residual volume to be dissolved 
                    dvd_res = dVd(ips,iz) - psd(ips,iz)*(4d0/3d0*pi*(10d0**ps(ips))**3d0)  ! residual 
                    
                    ! distributing the volume to whole radius 
                    ! the wrong one?
                    dvd_tmp = 0d0
                    do iips = ips+1,nps
                        if ( psd (iips,iz) /= 0d0 ) then 
                            dVd_tmp(iips) = dvd_res *dps(ips)/ ( psd (iips,iz) * (10d0**ps(iips))**2d0 )
                        else 
                            dVd_tmp(iips) = 0d0
                        endif 
                    enddo 
                    
                    ! correct one?
                    dVd_tmp = 0d0
                    if (.not.incld_rough) then 
                        dVd_tmp(ips+1:) = ( psd (ips+1:,iz) * (10d0**ps(ips+1:))**2d0 )
                    else
                        dVd_tmp(ips+1:) = ( psd (ips+1:,iz) * (10d0**ps(ips+1:))**2d0 *rough_c0*(10d0**ps(ips+1:))**rough_c1 )
                    endif 
                    
                    if (all(dVd_tmp == 0d0)) then 
                        print *,'all dissolved loc2?',ips, psd(ips+1:,iz)
                        psd_error_flg = .true.
                        return
                        stop
                    endif 
                    
                    ! scale with dvd_res*dps
                    dVd_tmp(ips+1:) = dVd_tmp(ips+1:)*dvd_res*dps(ips)/sum(dVd_tmp(ips+1:) * dps(ips+1:))
                    
                    ! dVd(ips+1:,iz) = dVd(ips+1:,iz) + dvd_res/(nps - ips)
                    dVd(ips+1:,iz) = dVd(ips+1:,iz) + dVd_tmp(ips+1:)
                    dVd(ips,iz) = dVd(ips,iz) - dvd_res
                    
                    if ( abs( (sum(dVd(:,iz) * dps(:)) - DV(iz))/DV(iz)) > tol ) then
                        print *, ' vol. balance failed somehow loc2 ',abs( (sum(dVd(:,iz) * dps(:)) - DV(iz))/DV(iz))
                        print *, iz, sum(dVd(:,iz) * dps(:)), DV(iz)
                        stop
                    endif 
                    
                    if (any(isnan(dVd(:,iz))) ) then 
                        print *, 'nan in dVd loc 2'
                        stop
                    endif 
                    
                    ! if (dVd(ips,iz)/(4d0/3d0*pi*(10d0**ps(ips))**3d0) > psd(ips,iz)) then 
                        ! print *, 'error: stop',psd(ips,iz),dVd(ips,iz)/(4d0/3d0*pi*(10d0**ps(ips))**3d0)
                        ! stop
                    ! endif 
                    
                    ! dpsd_tmp(ips,iz) = dpsd_tmp(ips,iz) - dVd(ips,iz)/(4d0/3d0*pi*(10d0**ps(ips))**3d0) 
                    dpsd_tmp(ips,iz) = dpsd_tmp(ips,iz) - psd(ips,iz) 
                endif 
            endif 
        
        elseif ( ips == nps .and. dVd(ips,iz) < 0d0 ) then 
            ! this is the max size dealt within the model 
            ! so if precipirated (dVd < 0), particle number must increase  
            ! (revised particle volumes) = (initial particle volumes) - (volume change) 
            ! psd'(ips,iz) * 4d0/3d0*pi*(10d0**ps(ips))**3d0 =  psd(ips,iz) * 4d0/3d0*pi*(10d0**ps(ips))**3d0 - dVd(ips,iz) 
            ! [ psd'(ips,iz) - psd(ips,iz) ] * 4d0/3d0*pi*(10d0**ps(ips))**3d0 = - dVd(ips,iz) 
            dpsd_tmp(ips,iz) = dpsd_tmp(ips,iz) - dVd(ips,iz)/(4d0/3d0*pi*(10d0**ps(ips))**3d0) 
        
        else 
            ps_new =  ( 4d0/3d0*pi*(10d0**ps(ips))**3d0 - dVd(ips,iz) /psd(ips,iz) )/(4d0/3d0*pi) 
            
            if (ps_new <= 0d0) then 
                ps_new = ps_min
                ps_newp = 10d0**ps(1)
                dpsd_tmp(1,iz) =  dpsd_tmp(1,iz) + psd(ips,iz)
                dpsd_tmp(ips,iz) =  dpsd_tmp(ips,iz) - psd(ips,iz)
                
                dvd_res = dVd(ips,iz) - psd(ips,iz)*(4d0/3d0*pi*(10d0**ps(ips))**3d0)  ! residual
                
                ! distributing the volume to whole radius 
                ! wrong one ?
                dvd_tmp = 0d0
                do iips = ips+1,nps
                    if ( psd (iips,iz) /= 0d0 ) then 
                        dVd_tmp(iips) = dvd_res *dps(ips)/ ( psd (iips,iz) * (10d0**ps(iips))**2d0 )
                    else 
                        dVd_tmp(iips) = 0d0
                    endif 
                enddo 
                
                ! correct one?
                dVd_tmp = 0d0
                if (.not.incld_rough) then 
                    dVd_tmp(ips+1:) = ( psd (ips+1:,iz) * (10d0**ps(ips+1:))**2d0 )
                else
                    dVd_tmp(ips+1:) = ( psd (ips+1:,iz) * (10d0**ps(ips+1:))**2d0 * rough_c0*(10d0**ps(ips+1:))**rough_c1 )
                endif 
                
                if (all(dVd_tmp == 0d0)) then 
                    print *,'all dissolved loc3?',ips, psd(ips+1:,iz)
                    psd_error_flg = .true.
                    return
                    stop
                endif 
                
                dVd_tmp(ips+1:) = dVd_tmp(ips+1:)*dvd_res*dps(ips)/sum(dVd_tmp(ips+1:) * dps(ips+1:))
                
                ! dVd(ips+1:,iz) = dVd(ips+1:,iz) + dvd_res/(nps - ips)
                dVd(ips+1:,iz) = dVd(ips+1:,iz) + dVd_tmp(ips+1:)
                dVd(ips,iz) = dVd(ips,iz) - dvd_res
                
                if ( abs( (sum(dVd(:,iz) * dps(:)) - DV(iz))/DV(iz)) > tol ) then
                    print *, ' vol. balance failed somehow loc2 ',abs( (sum(dVd(:,iz) * dps(:)) - DV(iz))/DV(iz))
                    print *, iz, sum(dVd(:,iz) * dps(:)), DV(iz)
                    stop
                endif 
                
                if (any(isnan(dVd(:,iz))) ) then 
                    print *, 'nan in dVd loc 3'
                    stop
                endif 
                
            else 
                ps_new =  ps_new**(1d0/3d0) 
                if (ps_new <= ps_min) then 
                    ips_new = 1
                elseif (ps_new >= ps_max) then 
                    ips_new = nps
                else 
                    do iips = 1, nps -1
                        if ( ( ps_new - 10d0**ps(iips) ) *  ( ps_new - 10d0**ps(iips+1) ) <= 0d0 ) then 
                            if ( log10(ps_new) <= 0.5d0*( ps(iips) + ps(iips+1) ) ) then 
                                ips_new = iips
                            else 
                                ips_new = iips + 1 
                            endif 
                            exit 
                        endif 
                    enddo 
                endif 
                ps_newp = 10d0**ps(ips_new)
                dpsd_tmp(ips_new,iz) = dpsd_tmp(ips_new,iz) + psd(ips,iz)*(ps_new/ps_newp)**3d0
                dpsd_tmp(ips,iz) =  dpsd_tmp(ips,iz) - psd(ips,iz)
                ! print *,iz,ips,dVd(ips,iz), psd(ips,iz)* 4d0/3d0 * pi * (10d0**ps(ips) - 10d0**ps(ips_new))**3d0 
            endif 
        
        endif 
        ! print *, iz, ips,ps_new,ps_newp
    enddo 
enddo 

if (any(isnan(psd))) then 
    print *, 'nan in psd'
    stop
endif 
if (any(psd<0d0)) then 
    print *, 'negative psd'
    stop
endif 
if (any(isnan(dvd))) then 
    print *, 'nan in dvd' 
    do iz = 1, nz
        do ips=1,nps
            if (isnan(dvd(ips,iz))) then 
                print *, 'ips,iz,dvd,psd',ips,iz,dvd(ips,iz),psd(ips,iz)
            endif 
        enddo 
    enddo 
    stop
endif 

psd_new = psd_new + dpsd_tmp
do iz = 1, nz
    if ( abs(DV(iz)) > tol  &
        & .and. abs ( ( sum( psd_old(:,iz) * 4d0/3d0 * pi * (10d0**ps(:))**3d0 * dps(:)) &
        & - sum( psd_new(:,iz) * 4d0/3d0 * pi * (10d0**ps(:))**3d0 * dps(:)) - DV(iz) ) / DV(iz) ) > tol ) then  
        print *, 'checking the vol. balance and failed ... ' &
            & , abs ( ( sum( psd_old(:,iz) * 4d0/3d0 * pi * (10d0**ps(:))**3d0 * dps(:)) &
            & - sum( psd_new(:,iz) * 4d0/3d0 * pi * (10d0**ps(:))**3d0 * dps(:)) - DV(iz) ) / DV(iz) )
        print *, iz, sum( psd_new(:,iz) * 4d0/3d0 * pi * (10d0**ps(:))**3d0 * dps(:)) &
            & ,sum( psd_old(:,iz) * 4d0/3d0 * pi * (10d0**ps(:))**3d0 * dps(:)) & 
            & ,sum( psd_new(:,iz) * 4d0/3d0 * pi * (10d0**ps(:))**3d0 * dps(:)) &
            &   -sum( psd_old(:,iz) * 4d0/3d0 * pi * (10d0**ps(:))**3d0 * dps(:))  &
            & ,DV(iz)
        ! stop 
        ! pause
        psd_error_flg = .true.
    endif 
enddo 

if (any(isnan(dpsd_tmp))) then 
    print *, 'nan in dpsd _rxn' 
    do iz = 1, nz
        do ips=1,nps
            if (isnan(dpsd_tmp(ips,iz))) then 
                print *, 'ips,iz,dpsd_tmp,psd',ips,iz,dpsd_tmp(ips,iz),psd(ips,iz)
            endif 
        enddo 
    enddo 
    stop
endif 

dpsd = dpsd + dpsd_tmp
   
endsubroutine psd_diss

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine psd_adv( &
    & nsp_sld,nps,nflx,iadv &! in
    & ,z,flx_sld,mv,dt,pi,tol,w,w0,dz &! in 
    & ,profdir,ipsd &! in
    & ,ps,dps,psd_pr &! in 
    & ,psd,dpsd &! inout
    & )
implicit none 

integer,intent(in)::nsp_sld,nps,nflx,ipsd,iadv
real(kind=8),intent(in)::dt,pi,tol,w0 
real(kind=8),dimension(nz),intent(in)::z,w,dz
real(kind=8),dimension(nsp_sld,nflx,nz),intent(in)::flx_sld
real(kind=8),dimension(nsp_sld),intent(in)::mv
real(kind=8),dimension(nps),intent(in)::ps,dps,psd_pr
character(256),intent(in)::profdir
real(kind=8),dimension(nps,nz),intent(inout)::psd,dpsd
! local 
real(kind=8),dimension(nps,nz)::psd_old,dpsd_tmp
real(kind=8),dimension(nz)::DV
integer iz,isps,ips

        
! attempt to do psd ( defined with particle number / bulk m3 / log (r) )
! assumptions: 
! 1. particle numbers are only affected by transport (including raining/dusting) 
! 2. dissolution does not change particle numbers: it only affect particle distribution 
! unless particle is the minimum radius. in this case particle can be lost via dissolution 
! 3. when a mineral precipitates, it is assumed to increase particle radius?
! e.g., when a 1 um of particle is dissolved by X m3, its radius is changed and this particle is put into a different bin of (smaller) radius 

! now accounting for advection 
! sum of volume change of minerals at iz is DV = sum(flx_sld(iadv,iz)*mv(:)*1d-6)*dt (m3 / m3) 
! in general sum(msld*mv*1d-6) (m3/m3) must be equal to sum( 4/3(pi)r3 * psd * dps) 
! so governing equation for msld must also be applicabple to psd?
! (wp_tmp*mp_tmp - w_tmp* m_tmp)/dz(iz)

dpsd_tmp = 0d0
psd_old = psd
do iz = 1, nz

    DV(iz) = 0d0
    do isps = 1,nsp_sld 
        DV(iz) = DV(iz) + flx_sld(isps, iadv ,iz)*mv(isps)*1d-6*dt 
    enddo 
    
    ! explicit way 
    if (iz == nz) then 
        ! dpsd_tmp(:,iz) = - ( w0 * 4d0/3d0*(pi)*(10d0**ps(:))**3d0  * psd_pr(:) * dps(:)  &
            ! & - w(iz) * 4d0/3d0*(pi)*(10d0**ps(:))**3d0  * psd(:,iz) * dps(:) ) /dz(iz) * dt
        dpsd_tmp(:,iz) = dpsd_tmp(:,iz) - ( w0 * psd_pr(:)  - w(iz) *  psd(:,iz) ) /dz(iz) * dt
        dpsd_tmp(:,iz) = (10d0**ps(:))**3d0 * ( w(iz) *  psd(:,iz) - w0 * psd_pr(:)) 
        dpsd_tmp(:,iz) =  w(iz) *  psd(:,iz) - w0 * psd_pr(:) 
    else 
        ! dpsd_tmp(:,iz) = - ( w(iz+1) * 4d0/3d0*(pi)*(10d0**ps(:))**3d0  * psd(:,iz+1) * dps(:)  &
            ! & - w(iz) * 4d0/3d0*(pi)*(10d0**ps(:))**3d0  * psd(:,iz) * dps(:) ) /dz(iz) * dt
        dpsd_tmp(:,iz) = dpsd_tmp(:,iz) - ( w(iz+1) * psd(:,iz+1) - w(iz) * psd(:,iz) ) /dz(iz) * dt
        dpsd_tmp(:,iz) = (10d0**ps(:))**3d0 * ( w(iz) *  psd(:,iz) - w(iz+1) * psd(:,iz+1)) 
        dpsd_tmp(:,iz) =  w(iz) *  psd(:,iz) - w(iz+1) * psd(:,iz+1)  
    endif 
    ! solution can diverge ?
    
    ! rather enforcing dpsd_tmp from DV
    ! i.e., sum(4d0/3d0*(pi)*(10d0**ps(:))**3d0 *  dpsd_tmp(:,iz) * dps(:)) - DV(iz) = 0
    ! sum(4d0/3d0*(pi)*(10d0**ps(:))**3d0 *  dpsd_tmp(:,iz) * dps(:)) = DV(iz)
    ! assumption is advection occurs in a linear function of psd 
    if (sum(dpsd_tmp(:,iz)) == 0d0 .and. DV(iz) == 0d0) cycle 
    ! if (sum(dpsd_tmp(:,iz)) == 0d0 .and. DV(iz) /= 0d0 ) dpsd_tmp(:,iz) = (10d0**ps(:))**3d0 * psd(:,iz) 
    dpsd_tmp(:,iz) = dpsd_tmp(:,iz)*DV(iz) / sum(4d0/3d0*(pi)*(10d0**ps(:))**3d0 *  dpsd_tmp(:,iz) * dps(:))
    
    
    if (DV(iz) > tol &
        & .and. abs((sum(4d0/3d0*(pi)*(10d0**ps(:))**3d0 *  dpsd_tmp(:,iz) * dps(:)) - DV(iz))/DV(iz)) > tol) then 
        print *, DV(iz), sum(4d0/3d0*(pi)*(10d0**ps(:))**3d0 *  dpsd_tmp(:,iz) * dps(:))
        pause
    endif 
    
enddo 

if (any(isnan(dpsd_tmp))) then 
    print *, 'nan in dpsd _adv' 
    do iz = 1, nz
        do ips=1,nps
            if (isnan(dpsd_tmp(ips,iz))) then 
                print *, 'ips,iz,dpsd_tmp,psd',ips,iz,dpsd_tmp(ips,iz),psd(ips,iz)
            endif 
        enddo 
    enddo 
    stop
endif 

dpsd = dpsd + dpsd_tmp
   
endsubroutine psd_adv

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine psd_adv_implicit( &
    & nsp_sld,nps,nflx,iadv &! in
    & ,z,flx_sld,mv,dt,pi,tol,w,w0,dz &! in 
    & ,profdir,ipsd &! in
    & ,ps,dps,psd_pr &! in 
    & ,psd,dpsd &! inout
    & )
implicit none 

integer,intent(in)::nsp_sld,nps,nflx,ipsd,iadv
real(kind=8),intent(in)::dt,pi,tol,w0 
real(kind=8),dimension(nz),intent(in)::z,w,dz
real(kind=8),dimension(nsp_sld,nflx,nz),intent(in)::flx_sld
real(kind=8),dimension(nsp_sld),intent(in)::mv
real(kind=8),dimension(nps),intent(in)::ps,dps,psd_pr
character(256),intent(in)::profdir
real(kind=8),dimension(nps,nz),intent(inout)::psd,dpsd
! local 
real(kind=8),dimension(nps,nz)::psd_old,dpsd_tmp
real(kind=8),dimension(nz)::DV
integer iz,isps,ips

real(kind=8) ::amx(nz,nz),ymx(nz)
integer ipiv(nz) 
integer info 

        
! attempt to do psd ( defined with particle number / bulk m3 / log (r) )
! assumptions: 
! 1. particle numbers are only affected by transport (including raining/dusting) 
! 2. dissolution does not change particle numbers: it only affect particle distribution 
! unless particle is the minimum radius. in this case particle can be lost via dissolution 
! 3. when a mineral precipitates, it is assumed to increase particle radius?
! e.g., when a 1 um of particle is dissolved by X m3, its radius is changed and this particle is put into a different bin of (smaller) radius 

! now accounting for advection 
! sum of volume change of minerals at iz is DV = sum(flx_sld(iadv,iz)*mv(:)*1d-6)*dt (m3 / m3) 
! in general sum(msld*mv*1d-6) (m3/m3) must be equal to sum( 4/3(pi)r3 * psd * dps) 
! so governing equation for msld must also be applicabple to psd?
! (wp_tmp*mp_tmp - w_tmp* m_tmp)/dz(iz)

dpsd_tmp = 0d0
psd_old = psd
do iz = 1, nz

    DV(iz) = 0d0
    do isps = 1,nsp_sld 
        DV(iz) = DV(iz) + flx_sld(isps, iadv ,iz)*mv(isps)*1d-6*dt 
    enddo 
    
enddo 

do iz = nz, 1, -1
    
    do ips = 1, nps
    
    amx = 0d0
    ymx = 0d0
    
    ! explicit way 
    if (iz == nz) then 
        ! dpsd_tmp(:,iz) = - ( w0 * 4d0/3d0*(pi)*(10d0**ps(:))**3d0  * psd_pr(:) * dps(:)  &
            ! & - w(iz) * 4d0/3d0*(pi)*(10d0**ps(:))**3d0  * psd(:,iz) * dps(:) ) /dz(iz) * dt
        dpsd_tmp(:,iz) = dpsd_tmp(:,iz) - ( w0 * psd_pr(:)  - w(iz) *  psd(:,iz) ) /dz(iz) * dt
        dpsd_tmp(:,iz) = (10d0**ps(:))**3d0 * ( w(iz) *  psd(:,iz) - w0 * psd_pr(:)) 
        dpsd_tmp(:,iz) =  w(iz) *  psd(:,iz) - w0 * psd_pr(:) 
    else 
        ! dpsd_tmp(:,iz) = - ( w(iz+1) * 4d0/3d0*(pi)*(10d0**ps(:))**3d0  * psd(:,iz+1) * dps(:)  &
            ! & - w(iz) * 4d0/3d0*(pi)*(10d0**ps(:))**3d0  * psd(:,iz) * dps(:) ) /dz(iz) * dt
        dpsd_tmp(:,iz) = dpsd_tmp(:,iz) - ( w(iz+1) * psd(:,iz+1) - w(iz) * psd(:,iz) ) /dz(iz) * dt
        dpsd_tmp(:,iz) = (10d0**ps(:))**3d0 * ( w(iz) *  psd(:,iz) - w(iz+1) * psd(:,iz+1)) 
        dpsd_tmp(:,iz) =  w(iz) *  psd(:,iz) - w(iz+1) * psd(:,iz+1)  
    endif 
    ! solution can diverge ?
    
    enddo 
    
    ! rather enforcing dpsd_tmp from DV
    ! i.e., sum(4d0/3d0*(pi)*(10d0**ps(:))**3d0 *  dpsd_tmp(:,iz) * dps(:)) - DV(iz) = 0
    ! sum(4d0/3d0*(pi)*(10d0**ps(:))**3d0 *  dpsd_tmp(:,iz) * dps(:)) = DV(iz)
    ! assumption is advection occurs in a linear function of psd 
    if (sum(dpsd_tmp(:,iz)) == 0d0 .and. DV(iz) == 0d0) cycle 
    ! if (sum(dpsd_tmp(:,iz)) == 0d0 .and. DV(iz) /= 0d0 ) dpsd_tmp(:,iz) = (10d0**ps(:))**3d0 * psd(:,iz) 
    dpsd_tmp(:,iz) = dpsd_tmp(:,iz)*DV(iz) / sum(4d0/3d0*(pi)*(10d0**ps(:))**3d0 *  dpsd_tmp(:,iz) * dps(:))
    
    
    if (DV(iz) > tol &
        & .and. abs((sum(4d0/3d0*(pi)*(10d0**ps(:))**3d0 *  dpsd_tmp(:,iz) * dps(:)) - DV(iz))/DV(iz)) > tol) then 
        print *, DV(iz), sum(4d0/3d0*(pi)*(10d0**ps(:))**3d0 *  dpsd_tmp(:,iz) * dps(:))
        pause
    endif 
    
enddo 

if (any(isnan(dpsd_tmp))) then 
    print *, 'nan in dpsd _adv' 
    do iz = 1, nz
        do ips=1,nps
            if (isnan(dpsd_tmp(ips,iz))) then 
                print *, 'ips,iz,dpsd_tmp,psd',ips,iz,dpsd_tmp(ips,iz),psd(ips,iz)
            endif 
        enddo 
    enddo 
    stop
endif 

dpsd = dpsd + dpsd_tmp
   
endsubroutine psd_adv_implicit

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine psd_dif( &
    & nsp_sld,nps,nflx,idif &! in
    & ,z,flx_sld,mv,dt,pi,tol &! in 
    & ,trans &! in
    & ,profdir,ipsd &! in
    & ,ps,dps &! in 
    & ,psd,dpsd &! inout
    & )
implicit none 

integer,intent(in)::nsp_sld,nps,nflx,ipsd,idif
real(kind=8),intent(in)::dt,pi,tol 
real(kind=8),dimension(nz),intent(in)::z
real(kind=8),dimension(nsp_sld,nflx,nz),intent(in)::flx_sld
real(kind=8),dimension(nz,nz,nsp_sld),intent(in)::trans
real(kind=8),dimension(nsp_sld),intent(in)::mv
real(kind=8),dimension(nps),intent(in)::ps,dps
character(256),intent(in)::profdir
real(kind=8),dimension(nps,nz),intent(inout)::psd,dpsd
! local 
real(kind=8),dimension(nps,nz)::psd_old,dpsd_tmp
real(kind=8),dimension(nz)::DV
integer iz,isps,ips,iiz

        
! attempt to do psd ( defined with particle number / bulk m3 / log (r) )
! assumptions: 
! 1. particle numbers are only affected by transport (including raining/dusting) 
! 2. dissolution does not change particle numbers: it only affect particle distribution 
! unless particle is the minimum radius. in this case particle can be lost via dissolution 
! 3. when a mineral precipitates, it is assumed to increase particle radius?
! e.g., when a 1 um of particle is dissolved by X m3, its radius is changed and this particle is put into a different bin of (smaller) radius 

! now accounting for diffusion (bio-mixing including tilling) 
! sum of volume change of minerals at iz is DV = sum(flx_sld(idif,iz)*mv(:)*1d-6)*dt (m3 / m3) 
! in general sum(msld*mv*1d-6) (m3/m3) must be equal to sum( 4/3(pi)r3 * psd * dps) 
! so governing equation for msld must also be applicabple to psd?
! do iiz = 1, nz
    ! if (trans(iiz,iz,isps)==0d0) cycle
        
    ! flx_sld(isps,idif,iz) = flx_sld(isps,idif,iz) + ( &
        ! & - trans(iiz,iz,isps)*msldx(isps,iiz) &
        ! & )
! enddo

dpsd_tmp = 0d0
psd_old = psd
do iz = 1, nz

    DV(iz) = 0d0
    do isps = 1,nsp_sld 
        DV(iz) = DV(iz) + flx_sld(isps, idif ,iz)*mv(isps)*1d-6*dt 
    enddo 
    
    ! explicit way 
    do iiz = 1, nz
            
        do isps = 1, nsp_sld
            if (trans(iiz,iz,isps)==0d0) cycle
            dpsd_tmp(:,iz) = dpsd_tmp(:,iz) + ( &
                ! & - trans(iiz,iz,isps)*sum( 4d0/3d0*(pi)*(10d0**ps(:))**3d0 * psd(:,iiz) * dps(:))  &
                & - trans(iiz,iz,isps)*psd(:,iiz)   &
                & * dt &
                & )
        enddo 
    enddo
    
    if (sum(dpsd_tmp(:,iz)) == 0d0 .and. DV(iz) == 0d0) cycle 
    dpsd_tmp(:,iz) = dpsd_tmp(:,iz)*DV(iz) / sum(4d0/3d0*(pi)*(10d0**ps(:))**3d0 *  dpsd_tmp(:,iz) * dps(:))
    
    if ( &
        ! & DV(iz) > tol &
        ! & .and.  &
        & abs((sum(4d0/3d0*(pi)*(10d0**ps(:))**3d0 *  dpsd_tmp(:,iz) * dps(:)) - DV(iz))/DV(iz)) > tol) then 
        print *, DV(iz), sum(4d0/3d0*(pi)*(10d0**ps(:))**3d0 *  dpsd_tmp(:,iz) * dps(:))
        pause
    endif 
    
enddo 

if (any(isnan(dpsd_tmp))) then 
    print *, 'nan in dpsd _dif' 
    do iz = 1, nz
        do ips=1,nps
            if (isnan(dpsd_tmp(ips,iz))) then 
                print *, 'ips,iz,dpsd_tmp,psd',ips,iz,dpsd_tmp(ips,iz),psd(ips,iz)
            endif 
        enddo 
    enddo 
    stop
endif 

dpsd = dpsd + dpsd_tmp
   
endsubroutine psd_dif

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine psd_dif_implicit( &
    & nsp_sld,nps,nflx,idif,iadv &! in
    & ,z,dz,flx_sld,mv,dt,pi,tol,w0,w,hr &! in 
    & ,incld_rough,rough_c0,rough_c1 &! in
    & ,trans &! in
    & ,msldx &! in 
    & ,profdir,ipsd &! in
    & ,psd,psd_pr,ps,dps &! in 
    & ,flgback &! inout
    & ,psdx &! out
    & )
implicit none 

integer,intent(in)::nsp_sld,nps,nflx,ipsd,idif,iadv
real(kind=8),intent(in)::dt,pi,tol,w0,rough_c0,rough_c1
real(kind=8),dimension(nz),intent(in)::z,dz,w,hr
real(kind=8),dimension(nsp_sld,nflx,nz),intent(in)::flx_sld
real(kind=8),dimension(nz,nz,nsp_sld),intent(in)::trans
real(kind=8),dimension(nsp_sld,nz),intent(in)::msldx
real(kind=8),dimension(nsp_sld),intent(in)::mv
real(kind=8),dimension(nps),intent(in)::ps,dps,psd_pr
character(256),intent(in)::profdir
logical,intent(in)::incld_rough
logical,intent(inout)::flgback
real(kind=8),dimension(nps,nz),intent(in)::psd
real(kind=8),dimension(nps,nz),intent(out)::psdx
! local 
real(kind=8),dimension(nps,nz)::psd_old,dpsd_tmp
real(kind=8),dimension(nz)::DV,kpsd
integer iz,isps,ips,iiz,row,col,ie,ie2,iips
real(kind=8) vol,surf,m_tmp,mp_tmp,mi_tmp,mprev_tmp,rxn_tmp,drxn_tmp,w_tmp,wp_tmp,trans_tmp

logical::dt_norm = .true.
real(kind=8),parameter::infinity = huge(0d0)
real(kind=8),parameter::threshold = 10d0
! real(kind=8),parameter::threshold = 3d0
! real(kind=8),parameter::corr = 1.5d0
real(kind=8),parameter::corr = exp(threshold)
integer,parameter :: iter_max = 50
real(kind=8) error 
integer iter

real(kind=8) amx3(nps*nz,nps*nz),ymx3(nps*nz),emx3(nps*nz)
integer ipiv3(nps*nz) 
integer info 
        
! do iz=1,nz
    ! hr(iz) = sum( 4d0*pi*(10d0**ps(:))**2d0*psd(:,iz)*dps(:) )
! enddo 
! do iz=1,nz
    ! hr(iz) = sum( 4d0*pi*(10d0**ps(:))**2d0*rough_c0*(10d0**ps(:))**rough_c1*psd(:,iz)*dps(:) )
! enddo 
! 
! attempt to do psd ( defined with particle number / bulk m3 / log (r) )
! solve as for msld 
! one of particle size equations are used to give massbalance constraint  

psdx = psd

kpsd = 0d0
do iz = 1, nz
    do isps = 1,nsp_sld 
        DV(iz) = DV(iz) + flx_sld(isps, 4 + isps,iz)*mv(isps)*1d-6
    enddo 
    kpsd(iz) = DV(iz) / hr(iz) / sum( msldx(:,iz) * mv(:) * 1d-6 )
enddo 


error = 1d4 
iter = 1

do while (error > tol) 

    amx3 = 0d0
    ymx3 = 0d0

    do iz = 1, nz
        
        do ips = 1, nps
        
            row =  iz  + ( ips - 1 ) * nz 
            
            vol  = 4d0/3d0*pi*(10d0**ps(ips))**3d0
            surf = 4d0*pi*(10d0**ps(ips))**2d0
                    
            m_tmp = vol * psdx(ips,iz) * dps(ips)
            mprev_tmp = vol * psd(ips,iz) * dps(ips)        
            rxn_tmp = vol * psdx(ips,iz)*dps(ips) &
                & * surf * psdx(ips,iz)*dps(ips) * kpsd(iz) 
            
            mi_tmp = vol * psd_pr(ips) * dps(ips)
            mp_tmp = vol * psdx(ips,min(iz+1,nz)) * dps(ips)
            
            drxn_tmp = & 
                & vol * 1d0 * dps(ips) &
                & * surf * psdx(ips,iz) * dps(ips) * kpsd(iz) &
                & + vol * psdx(ips,iz) * dps(ips) &
                & * surf * 1d0 * dps(ips) * kpsd(iz) 
            
            w_tmp = w(iz)
            wp_tmp = w(min(nz,iz+1))
            
            if (iz==nz) then 
                mp_tmp = mi_tmp
                wp_tmp = w0
            endif 

            amx3(row,row) = ( &
                & vol * dps(iz) * 1d0  /  merge(1d0,dt,dt_norm)     &
                & + vol * dps(iz) * w_tmp / dz(iz)  *merge(dt,1d0,dt_norm)    &
                & + drxn_tmp * merge(dt,1d0,dt_norm) &
                & ) &
                & * psdx(ips,iz)

            ymx3(row) = ( &
                & ( m_tmp - mprev_tmp ) / merge(1d0,dt,dt_norm) &
                & -( wp_tmp * mp_tmp - w_tmp * m_tmp ) / dz(iz) * merge(dt,1d0,dt_norm)  &
                & + rxn_tmp * merge(dt,1d0,dt_norm) &
                & ) &
                & * 1d0
                        
            if (iz/=nz) then 
                col = iz + 1  + ( ips - 1 ) * nz 
                amx3(row,col) = &
                    & (- vol * dps(iz) * wp_tmp / dz(iz)) * merge(dt,1d0,dt_norm) * psdx(ips,min(iz+1,nz))
            endif 
            
            do iiz = 1, nz
                col = iiz  + ( ips - 1 ) * nz 
                trans_tmp = sum(trans(iiz,iz,:))/nsp_sld
                if (trans_tmp == 0d0) cycle
                    
                amx3(row,col) = amx3(row,col) - trans_tmp * vol * psd(ips,iiz) * dps(ips)  * merge(dt,1d0,dt_norm) 
                ymx3(row) = ymx3(row) - trans_tmp * vol * psd(ips,iiz) * dps(ips)  * merge(dt,1d0,dt_norm) 
            enddo
            
            
            ! if (ips == nps) then 
            
                ! amx3(row,:) = 0d0
                ! ymx3(row  ) = 0d0
                
                
                ! ymx3(row) = ( &
                    ! &  sum( msldx(:,iz) * mv(:) * 1d-6 ) - sum ( 4d0/3d0*pi*(10d0**ps(:))**3d0 * psdx(:,iz) * dps(:) ) &
                    ! & ) &
                    ! & * 1d0
                    
                ! do iips = 1, nps
                    ! col = iz  + ( iips - 1 ) * nz 
                    ! amx3(row,col) = ( &
                        ! &   -  ( 4d0/3d0*pi*(10d0**ps(iips))**3d0 * psdx(iips,iz) * dps(iips) )  &
                        ! & ) &
                        ! & * 1d0
                
                ! enddo 
            
            ! endif 
            
        enddo

    enddo 
    
    ymx3=-1.0d0*ymx3

    if (any(isnan(amx3)).or.any(isnan(ymx3)).or.any(amx3>infinity).or.any(ymx3>infinity)) then 
    ! if (.true.) then 
        print*,'PSD: error in mtx'
        print*,'PSD: any(isnan(amx3)),any(isnan(ymx3))'
        print*,any(isnan(amx3)),any(isnan(ymx3))

        if (any(isnan(ymx3))) then 
            do ie = 1,nps*(nz)
                if (isnan(ymx3(ie))) then 
                    print*,'NAN is here...',ie
                endif
            enddo
        endif


        if (any(isnan(amx3))) then 
            do ie = 1,nps*(nz)
                do ie2 = 1,nps*(nz)
                    if (isnan(amx3(ie,ie2))) then 
                        print*,'PSD: NAN is here...',ie,ie2
                    endif
                enddo
            enddo
        endif
        
! #ifdef errmtx_printout
        ! open(unit=11,file='amx.txt',status = 'replace')
        ! open(unit=12,file='ymx.txt',status = 'replace')
        ! do ie = 1,nps*(nz)
            ! write(11,*) (amx3(ie,ie2),ie2 = 1,nps*nz)
            ! write(12,*) ymx3(ie)
        ! enddo 
        ! close(11)
        ! close(12) 
! #endif 
        stop
    endif
    
    call DGESV(nps*(Nz),int(1),amx3,nps*(Nz),IPIV3,ymx3,nps*(Nz),INFO) 

    if (any(isnan(ymx3))) then
        print*,'PSD: error in soultion'
        
! #ifdef errmtx_printout
        ! open(unit=11,file='amx.txt',status = 'replace')
        ! open(unit=12,file='ymx.txt',status = 'replace')
        ! do ie = 1,nps*(nz)
            ! write(11,*) (amx3(ie,ie2),ie2 = 1,nps*nz)
            ! write(12,*) ymx3(ie)
        ! enddo 
        ! close(11)
        ! close(12)   
! #endif     
        
        flgback = .true.
        ! pause
        exit
    endif

    do iz = 1, nz
        do ips = 1, nps
            
            row =  iz  + ( ips - 1 ) * nz 

            if (isnan(ymx3(row))) then 
                print *,'PSD: nan at', iz,ips
                stop
            endif

            if ((.not.isnan(ymx3(row))).and.ymx3(row) >threshold) then 
                psdx(ips,iz) = psdx(ips,iz)*corr
            else if (ymx3(row) < -threshold) then 
                psdx(ips,iz) = psdx(ips,iz)/corr
            else   
                psdx(ips,iz) = psdx(ips,iz)*exp(ymx3(row))
            endif
            
            ! if ( psdx(ips,iz)<msldth(ips)) then ! too small trancate value and not be accounted for error 
                ! psdx(ips,iz)=msldth(ips)
                ! ymx3(row) = 0d0
            ! endif
        enddo 
        
    end do 

    error = maxval(exp(abs(ymx3))) - 1.0d0
    
    if (isnan(error)) error = 1d4

    if ( isnan(error).or.info/=0 .or. any(isnan(psdx)) ) then 
        error = 1d3
        print*, 'PSD: !! error is NaN; values are returned to those before iteration with reducing dt'
        print*, 'PSD: isnan(error), info/=0,any(isnan(pdsx))'
        print*, isnan(error), info, any(isnan(psdx)) 
        
! #ifdef errmtx_printout
        ! open(unit=11,file='amx.txt',status = 'replace')
        ! open(unit=12,file='ymx.txt',status = 'replace')
        ! do ie = 1,nps*(nz)
            ! write(11,*) (amx3(ie,ie2),ie2 = 1,nps*nz)
            ! write(12,*) ymx3(ie)
        ! enddo 
        ! close(11)
        ! close(12)         
! #endif 
        
        ! dt = dt/10d0
        flgback = .true.
        ! pause
        exit
        
        
        ! stop
    endif

    print '(a,E11.3,a,i0,a,E11.3)', 'PSD: iteration error = ',error, ', iteration = ',iter,', time step [yr] = ',dt
    iter = iter + 1 
    
    if (iter > iter_Max ) then
    ! if (iter > iter_Max .or. (method_precalc .and. error > infinity)) then
        ! dt = dt/1.01d0
        ! dt = dt/10d0
        if (dt==0d0) then 
            print *, 'dt==0d0; stop'
        
! #ifdef errmtx_printout
            ! open(unit=11,file='amx.txt',status = 'replace')
            ! open(unit=12,file='ymx.txt',status = 'replace')
            ! do ie = 1,nsp3*(nz)
                ! write(11,*) (amx3(ie,ie2),ie2 = 1,nsp3*nz)
                ! write(12,*) ymx3(ie)
            ! enddo 
            ! close(11)
            ! close(12)      
! #endif 
            stop
        endif 
        flgback = .true.
        
        exit 
    end if

enddo 
   
endsubroutine psd_dif_implicit

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine psd_implicit_all( &
    & nsp_sld,nps,nflx,idif,iadv &! in
    & ,z,dz,flx_sld,mv,dt,pi,tol,w0,w,hr &! in 
    & ,incld_rough,rough_c0,rough_c1 &! in
    & ,trans &! in
    & ,msldx &! in 
    & ,profdir,ipsd &! in
    & ,psd,psd_pr,ps,dps,dpsd,psd_rain &! in 
    & ,flgback &! inout
    & ,psdx &! out
    & )
implicit none 

integer,intent(in)::nsp_sld,nps,nflx,ipsd,idif,iadv
real(kind=8),intent(in)::dt,pi,tol,w0,rough_c0,rough_c1
real(kind=8),dimension(nz),intent(in)::z,dz,w,hr
real(kind=8),dimension(nsp_sld,nflx,nz),intent(in)::flx_sld
real(kind=8),dimension(nz,nz,nsp_sld),intent(in)::trans
real(kind=8),dimension(nsp_sld,nz),intent(in)::msldx
real(kind=8),dimension(nsp_sld),intent(in)::mv
real(kind=8),dimension(nps),intent(in)::ps,dps,psd_pr
character(256),intent(in)::profdir
logical,intent(in)::incld_rough
logical,intent(inout)::flgback
real(kind=8),dimension(nps,nz),intent(in)::psd,dpsd,psd_rain
real(kind=8),dimension(nps,nz),intent(out)::psdx
! local 
real(kind=8),dimension(nps,nz)::psd_old,dpsd_tmp
real(kind=8),dimension(nz)::DV,kpsd
integer iz,isps,ips,iiz,row,col,ie,ie2,iips
real(kind=8) vol,surf,m_tmp,mp_tmp,mi_tmp,mprev_tmp,rxn_tmp,drxn_tmp,w_tmp,wp_tmp,trans_tmp,msupp_tmp

logical::dt_norm = .true.
real(kind=8),parameter::infinity = huge(0d0)
real(kind=8),parameter::threshold = 10d0
! real(kind=8),parameter::threshold = 3d0
! real(kind=8),parameter::corr = 1.5d0
real(kind=8),parameter::corr = exp(threshold)
integer,parameter :: iter_max = 50
real(kind=8) error,fact 
integer iter

real(kind=8) amx3(nps*nz,nps*nz),ymx3(nps*nz),emx3(nps*nz)
integer ipiv3(nps*nz) 
integer info 
        
! do iz=1,nz
    ! hr(iz) = sum( 4d0*pi*(10d0**ps(:))**2d0*psd(:,iz)*dps(:) )
! enddo 
! do iz=1,nz
    ! hr(iz) = sum( 4d0*pi*(10d0**ps(:))**2d0*rough_c0*(10d0**ps(:))**rough_c1*psd(:,iz)*dps(:) )
! enddo 
! 
! attempt to do psd ( defined with particle number / bulk m3 / log (r) )
! solve as for msld 
! one of particle size equations are used to give massbalance constraint  

psdx = psd

kpsd = 0d0
do iz = 1, nz
    do isps = 1,nsp_sld 
        DV(iz) = DV(iz) + flx_sld(isps, 4 + isps,iz)*mv(isps)*1d-6
    enddo 
    kpsd(iz) = DV(iz) / hr(iz) !/ sum( msldx(:,iz) * mv(:) * 1d-6 )
enddo 


error = 1d4 
iter = 1

do while (error > tol) 

    amx3 = 0d0
    ymx3 = 0d0

    do iz = 1, nz
        
        do ips = 1, nps
        
            row =  iz  + ( ips - 1 ) * nz 
            
            vol  = 4d0/3d0*pi*(10d0**ps(ips))**3d0
            surf = 4d0*pi*(10d0**ps(ips))**2d0
                    
            m_tmp = vol * psdx(ips,iz) * dps(ips)
            mprev_tmp = vol * psd(ips,iz) * dps(ips)        
            ! rxn_tmp = vol * psdx(ips,iz)*dps(ips) &
                ! & * surf * psdx(ips,iz)*dps(ips) * kpsd(iz) 
            ! rxn_tmp = surf * psdx(ips,iz)*dps(ips) * kpsd(iz) 
            rxn_tmp =  - vol * dpsd(ips,iz) * dps(ips) / dt 
            
            msupp_tmp = vol * psd_rain(ips,iz) * dps(ips)  / dt
            
            mi_tmp = vol * psd_pr(ips) * dps(ips)
            mp_tmp = vol * psdx(ips,min(iz+1,nz)) * dps(ips)
            
            ! drxn_tmp = & 
                ! & vol * 1d0 * dps(ips) &
                ! & * surf * psdx(ips,iz) * dps(ips) * kpsd(iz) &
                ! & + vol * psdx(ips,iz) * dps(ips) &
                ! & * su
            ! drxn_tmp = surf * 1d0 * dps(ips) * kpsd(iz) 
            drxn_tmp = 0d0 
            
            w_tmp = w(iz)
            wp_tmp = w(min(nz,iz+1))
            
            if (iz==nz) then 
                mp_tmp = mi_tmp
                wp_tmp = w0
            endif 

            amx3(row,row) = ( &
                & vol * dps(iz) * 1d0  /  merge(1d0,dt,dt_norm)     &
                & + vol * dps(iz) * w_tmp / dz(iz)  *merge(dt,1d0,dt_norm)    &
                & + drxn_tmp * merge(dt,1d0,dt_norm) &
                & ) &
                & * psdx(ips,iz)

            ymx3(row) = ( &
                & ( m_tmp - mprev_tmp ) / merge(1d0,dt,dt_norm) &
                & -( wp_tmp * mp_tmp - w_tmp * m_tmp ) / dz(iz) * merge(dt,1d0,dt_norm)  &
                & + rxn_tmp * merge(dt,1d0,dt_norm) &
                & - msupp_tmp * merge(dt,1d0,dt_norm) &
                & ) &
                & * 1d0
                        
            if (iz/=nz) then 
                col = iz + 1  + ( ips - 1 ) * nz 
                amx3(row,col) = &
                    & (- vol * dps(iz) * wp_tmp / dz(iz)) * merge(dt,1d0,dt_norm) * psdx(ips,min(iz+1,nz))
            endif 
            
            do iiz = 1, nz
                col = iiz  + ( ips - 1 ) * nz 
                trans_tmp = sum(trans(iiz,iz,:))/nsp_sld
                if (trans_tmp == 0d0) cycle
                    
                amx3(row,col) = amx3(row,col) - trans_tmp * vol * psdx(ips,iiz) * dps(ips)  * merge(dt,1d0,dt_norm) 
                ymx3(row) = ymx3(row) - trans_tmp * vol * psdx(ips,iiz) * dps(ips)  * merge(dt,1d0,dt_norm) 
            enddo
            
            
            ! if (ips == nps) then 
            
                ! amx3(row,:) = 0d0
                ! ymx3(row  ) = 0d0
                
                
                ! ymx3(row) = ( &
                    ! &  sum( msldx(:,iz) * mv(:) * 1d-6 ) - sum ( 4d0/3d0*pi*(10d0**ps(:))**3d0 * psdx(:,iz) * dps(:) ) &
                    ! & ) &
                    ! & * 1d0
                    
                ! do iips = 1, nps
                    ! col = iz  + ( iips - 1 ) * nz 
                    ! amx3(row,col) = ( &
                        ! &   -  ( 4d0/3d0*pi*(10d0**ps(iips))**3d0 * psdx(iips,iz) * dps(iips) )  &
                        ! & ) &
                        ! & * 1d0
                
                ! enddo 
            
            ! endif 
            
            fact = max( abs( ymx3(row) ), maxval( abs( amx3(row,:) ) ) )
            
            ymx3(row) = ymx3(row) / fact
            amx3(row,:) = amx3(row,:) / fact
            
        enddo

    enddo 
    
    ymx3=-1.0d0*ymx3

    if (any(isnan(amx3)).or.any(isnan(ymx3)).or.any(amx3>infinity).or.any(ymx3>infinity)) then 
    ! if (.true.) then 
        print*,'PSD: error in mtx'
        print*,'PSD: any(isnan(amx3)),any(isnan(ymx3))'
        print*,any(isnan(amx3)),any(isnan(ymx3))

        if (any(isnan(ymx3))) then 
            do ie = 1,nps*(nz)
                if (isnan(ymx3(ie))) then 
                    print*,'NAN is here...',ie
                endif
            enddo
        endif


        if (any(isnan(amx3))) then 
            do ie = 1,nps*(nz)
                do ie2 = 1,nps*(nz)
                    if (isnan(amx3(ie,ie2))) then 
                        print*,'PSD: NAN is here...',ie,ie2
                    endif
                enddo
            enddo
        endif
        
! #ifdef errmtx_printout
        ! open(unit=11,file='amx.txt',status = 'replace')
        ! open(unit=12,file='ymx.txt',status = 'replace')
        ! do ie = 1,nps*(nz)
            ! write(11,*) (amx3(ie,ie2),ie2 = 1,nps*nz)
            ! write(12,*) ymx3(ie)
        ! enddo 
        ! close(11)
        ! close(12) 
! #endif 
        stop
    endif
    
    call DGESV(nps*(Nz),int(1),amx3,nps*(Nz),IPIV3,ymx3,nps*(Nz),INFO) 

    if (any(isnan(ymx3))) then
        print*,'PSD: error in soultion'
        
! #ifdef errmtx_printout
        ! open(unit=11,file='amx.txt',status = 'replace')
        ! open(unit=12,file='ymx.txt',status = 'replace')
        ! do ie = 1,nps*(nz)
            ! write(11,*) (amx3(ie,ie2),ie2 = 1,nps*nz)
            ! write(12,*) ymx3(ie)
        ! enddo 
        ! close(11)
        ! close(12)   
! #endif     
        
        flgback = .true.
        ! pause
        exit
    endif

    do iz = 1, nz
        do ips = 1, nps
            
            row =  iz  + ( ips - 1 ) * nz 

            if (isnan(ymx3(row))) then 
                print *,'PSD: nan at', iz,ips
                stop
            endif

            if ((.not.isnan(ymx3(row))).and.ymx3(row) >threshold) then 
                psdx(ips,iz) = psdx(ips,iz)*corr
            else if (ymx3(row) < -threshold) then 
                psdx(ips,iz) = psdx(ips,iz)/corr
            else   
                psdx(ips,iz) = psdx(ips,iz)*exp(ymx3(row))
            endif
            
            ! if ( psdx(ips,iz)<msldth(ips)) then ! too small trancate value and not be accounted for error 
                ! psdx(ips,iz)=msldth(ips)
                ! ymx3(row) = 0d0
            ! endif
        enddo 
        
    end do 

    error = maxval(exp(abs(ymx3))) - 1.0d0
    
    if (isnan(error)) error = 1d4

    if ( isnan(error).or.info/=0 .or. any(isnan(psdx)) ) then 
        error = 1d3
        print*, 'PSD: !! error is NaN; values are returned to those before iteration with reducing dt'
        print*, 'PSD: isnan(error), info/=0,any(isnan(pdsx))'
        print*, isnan(error), info, any(isnan(psdx)) 
        
! #ifdef errmtx_printout
        ! open(unit=11,file='amx.txt',status = 'replace')
        ! open(unit=12,file='ymx.txt',status = 'replace')
        ! do ie = 1,nps*(nz)
            ! write(11,*) (amx3(ie,ie2),ie2 = 1,nps*nz)
            ! write(12,*) ymx3(ie)
        ! enddo 
        ! close(11)
        ! close(12)         
! #endif 
        
        ! dt = dt/10d0
        flgback = .true.
        ! pause
        exit
        
        
        ! stop
    endif

    print '(a,E11.3,a,i0,a,E11.3)', 'PSD: iteration error = ',error, ', iteration = ',iter,', time step [yr] = ',dt
    iter = iter + 1 
    
    if (iter > iter_Max ) then
    ! if (iter > iter_Max .or. (method_precalc .and. error > infinity)) then
        ! dt = dt/1.01d0
        ! dt = dt/10d0
        if (dt==0d0) then 
            print *, 'dt==0d0; stop'
        
! #ifdef errmtx_printout
            ! open(unit=11,file='amx.txt',status = 'replace')
            ! open(unit=12,file='ymx.txt',status = 'replace')
            ! do ie = 1,nsp3*(nz)
                ! write(11,*) (amx3(ie,ie2),ie2 = 1,nsp3*nz)
                ! write(12,*) ymx3(ie)
            ! enddo 
            ! close(11)
            ! close(12)      
! #endif 
            stop
        endif 
        flgback = .true.
        
        exit 
    end if

enddo 
   
endsubroutine psd_implicit_all

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine psd_implicit_all_v2( &
    & nsp_sld,nps,nflx,idif,iadv,nflx_psd &! in
    & ,z,dz,flx_sld,mv,dt,pi,tol,w0,w,hr,poro,poroi,poroprev &! in 
    & ,incld_rough,rough_c0,rough_c1 &! in
    & ,trans &! in
    & ,msldx &! in 
    & ,profdir,ipsd &! in
    & ,psd,psd_pr,ps,dps,dpsd,psd_rain &! in 
    & ,flgback &! inout
    & ,psdx,flx_psd &! out
    & )
implicit none 

integer,intent(in)::nsp_sld,nps,nflx,ipsd,idif,iadv,nflx_psd
real(kind=8),intent(in)::dt,pi,tol,w0,rough_c0,rough_c1,poroi
real(kind=8),dimension(nz),intent(in)::z,dz,w,hr,poro,poroprev
real(kind=8),dimension(nsp_sld,nflx,nz),intent(in)::flx_sld
real(kind=8),dimension(nz,nz,nsp_sld),intent(in)::trans
real(kind=8),dimension(nsp_sld,nz),intent(in)::msldx
real(kind=8),dimension(nsp_sld),intent(in)::mv
real(kind=8),dimension(nps),intent(in)::ps,dps,psd_pr
character(256),intent(in)::profdir
logical,intent(in)::incld_rough
logical,intent(inout)::flgback
real(kind=8),dimension(nps,nz),intent(in)::psd,dpsd,psd_rain
real(kind=8),dimension(nps,nz),intent(out)::psdx
! local 
real(kind=8),dimension(nps,nz)::psd_old,dpsd_tmp
real(kind=8),dimension(nz)::DV,kpsd,sporo
integer iz,isps,ips,iiz,row,col,ie,ie2,iips
real(kind=8) vol,surf,m_tmp,mp_tmp,mi_tmp,mprev_tmp,rxn_tmp,drxn_tmp,w_tmp,wp_tmp,trans_tmp,msupp_tmp  &
    & ,sporo_tmp, sporop_tmp,sporoprev_tmp,dtinv,dzinv

logical::dt_norm = .true.
real(kind=8),parameter::infinity = huge(0d0)
real(kind=8),parameter::threshold = 20d0
! real(kind=8),parameter::threshold = 3d0
! real(kind=8),parameter::corr = 1.5d0
real(kind=8),parameter::corr = exp(threshold)
integer,parameter :: iter_max = 50
! integer,parameter :: nflx_psd = 6
real(kind=8) error,fact,flx_max,flx_max_max
real(kind=8) :: flx_tol = 1d-3
real(kind=8) :: flx_max_tol = 1d-6
real(kind=8) :: dt_th = 1d-6
real(kind=8) :: fact_tol(nps) 
integer iter,iflx
real(kind=8),dimension(nps,nflx_psd,nz),intent(out) :: flx_psd ! itflx,iadv,idif,irain,irxn,ires
integer  itflx_psd,iadv_psd,idif_psd,irain_psd,irxn_psd,ires_psd
data itflx_psd,iadv_psd,idif_psd,irain_psd,irxn_psd,ires_psd/1,2,3,4,5,6/
character(5),dimension(nflx_psd)::chrflx_psd
character(20) chrfmt
! logical :: chkflx = .false.
logical :: chkflx = .true.

real(kind=8) amx3(nz,nz),ymx3(nz),emx3(nps),emx3_loc(nz)
integer ipiv3(nz) 
integer info 
        
! do iz=1,nz
    ! hr(iz) = sum( 4d0*pi*(10d0**ps(:))**2d0*psd(:,iz)*dps(:) )
! enddo 
! do iz=1,nz
    ! hr(iz) = sum( 4d0*pi*(10d0**ps(:))**2d0*rough_c0*(10d0**ps(:))**rough_c1*psd(:,iz)*dps(:) )
! enddo 
! 
! attempt to do psd ( defined with particle number / bulk m3 / log (r) )
! solve as for msld 
! one of particle size equations are used to give massbalance constraint  


chrflx_psd = (/'tflx ','adv  ','dif  ','rain ','rxn  ','res  '/)

dtinv = 1d0/dt

sporo = 1d0 - poro
sporo = 1d0 

psdx = psd

kpsd = 0d0
do iz = 1, nz
    do isps = 1,nsp_sld 
        DV(iz) = DV(iz) + flx_sld(isps, 4 + isps,iz)*mv(isps)*1d-6
    enddo 
    kpsd(iz) = DV(iz) / hr(iz) !/ sum( msldx(:,iz) * mv(:) * 1d-6 )
enddo 


error = 1d4 
iter = 1
emx3 = error

do ips =1,nps
    fact_tol(ips) = maxval(psd(ips,:)) * 1d-12
enddo 
! fact_tol = 1d0

! do while (error > tol*fact_tol) 
do while (error > 1d0) 
! do while ( any (emx3 > fact_tol )  ) 
    
    
    do ips = 1, nps
    
        if (emx3(ips) <= fact_tol(ips)) cycle

        amx3 = 0d0
        ymx3 = 0d0
        
        do iz = 1, nz
        
            row =  iz   
            
            vol  = 4d0/3d0*pi*(10d0**ps(ips))**3d0
            surf = 4d0*pi*(10d0**ps(ips))**2d0
                    
            m_tmp = vol * psdx(ips,iz) * dps(ips)
            mprev_tmp = vol * psd(ips,iz) * dps(ips)        
            ! rxn_tmp = vol * psdx(ips,iz)*dps(ips) &
                ! & * surf * psdx(ips,iz)*dps(ips) * kpsd(iz) 
            ! rxn_tmp = surf * psdx(ips,iz)*dps(ips) * kpsd(iz) 
            ! rxn_tmp =  - vol * dpsd(ips,iz) * dps(ips) / dt 
            rxn_tmp =  - vol * dpsd(ips,iz) * dps(ips) * dtinv
            
            ! msupp_tmp = vol * psd_rain(ips,iz) * dps(ips)  / dt
            msupp_tmp = vol * psd_rain(ips,iz) * dps(ips) * dtinv
            
            mi_tmp = vol * psd_pr(ips) * dps(ips)
            mp_tmp = vol * psdx(ips,min(iz+1,nz)) * dps(ips)
            
            dzinv = 1d0/dz(iz)
            
            ! drxn_tmp = & 
                ! & vol * 1d0 * dps(ips) &
                ! & * surf * psdx(ips,iz) * dps(ips) * kpsd(iz) &
                ! & + vol * psdx(ips,iz) * dps(ips) &
                ! & * su
            ! drxn_tmp = surf * 1d0 * dps(ips) * kpsd(iz) 
            drxn_tmp = 0d0 
            
            w_tmp = w(iz)
            wp_tmp = w(min(nz,iz+1))

            sporo_tmp = 1d0-poro(iz)
            sporop_tmp = 1d0-poro(min(nz,iz+1))
            sporoprev_tmp = 1d0-poroprev(iz)
            
            if (iz==nz) then 
                mp_tmp = mi_tmp
                wp_tmp = w0
                sporop_tmp = 1d0- poroi
            endif 
            
            sporo_tmp = 1d0
            sporop_tmp = 1d0
            sporoprev_tmp = 1d0

            amx3(row,row) = ( &
                ! & sporo_tmp * vol * dps(iz) * 1d0  /  merge(1d0,dt,dt_norm)     &
                & sporo_tmp * vol * dps(iz) * 1d0  *  merge(1d0,dtinv,dt_norm)     &
                ! & + sporo_tmp * vol * dps(iz) * w_tmp / dz(iz)  *merge(dt,1d0,dt_norm)    &
                & + sporo_tmp * vol * dps(iz) * w_tmp * dzinv  *merge(dt,1d0,dt_norm)    &
                & + sporo_tmp * drxn_tmp * merge(dt,1d0,dt_norm) &
                & ) &
                & * psdx(ips,iz)

            ymx3(row) = ( &
                ! & ( sporo_tmp * m_tmp - sporoprev_tmp*mprev_tmp ) / merge(1d0,dt,dt_norm) &
                & ( sporo_tmp * m_tmp - sporoprev_tmp*mprev_tmp ) * merge(1d0,dtinv,dt_norm) &
                ! & -( sporop_tmp * wp_tmp * mp_tmp - sporo_tmp * w_tmp * m_tmp ) / dz(iz) * merge(dt,1d0,dt_norm)  &
                & -( sporop_tmp * wp_tmp * mp_tmp - sporo_tmp * w_tmp * m_tmp ) * dzinv * merge(dt,1d0,dt_norm)  &
                & + sporo_tmp* rxn_tmp * merge(dt,1d0,dt_norm) &
                & - sporo_tmp* msupp_tmp * merge(dt,1d0,dt_norm) &
                & ) &
                & * 1d0
                        
            if (iz/=nz) then 
                col = iz + 1  
                amx3(row,col) = &
                    ! & (- sporop_tmp * vol * dps(iz) * wp_tmp / dz(iz)) * merge(dt,1d0,dt_norm) * psdx(ips,min(iz+1,nz))
                    & (- sporop_tmp * vol * dps(iz) * wp_tmp * dzinv) * merge(dt,1d0,dt_norm) * psdx(ips,min(iz+1,nz))
            endif 
            
            do iiz = 1, nz
                col = iiz   
                trans_tmp = sum(trans(iiz,iz,:))/nsp_sld
                if (trans_tmp == 0d0) cycle
                    
                amx3(row,col) = amx3(row,col) - trans_tmp * sporo(iiz) * vol * psdx(ips,iiz) * dps(ips)  * merge(dt,1d0,dt_norm) 
                ymx3(row) = ymx3(row) - trans_tmp * sporo(iiz) * vol * psdx(ips,iiz) * dps(ips)  * merge(dt,1d0,dt_norm) 
            enddo
            
            
            ! if (ips == nps) then 
            
                ! amx3(row,:) = 0d0
                ! ymx3(row  ) = 0d0
                
                
                ! ymx3(row) = ( &
                    ! &  sum( msldx(:,iz) * mv(:) * 1d-6 ) - sum ( 4d0/3d0*pi*(10d0**ps(:))**3d0 * psdx(:,iz) * dps(:) ) &
                    ! & ) &
                    ! & * 1d0
                    
                ! do iips = 1, nps
                    ! col = iz  + ( iips - 1 ) * nz 
                    ! amx3(row,col) = ( &
                        ! &   -  ( 4d0/3d0*pi*(10d0**ps(iips))**3d0 * psdx(iips,iz) * dps(iips) )  &
                        ! & ) &
                        ! & * 1d0
                
                ! enddo 
            
            ! endif 
            
            ! fact = max( abs( ymx3(row) ), maxval( abs( amx3(row,:) ) ) )
            
            ! ymx3(row) = ymx3(row) / fact
            ! amx3(row,:) = amx3(row,:) / fact
            
        enddo
    
        ymx3=-1.0d0*ymx3

        if (any(isnan(amx3)).or.any(isnan(ymx3)).or.any(amx3>infinity).or.any(ymx3>infinity)) then 
        ! if (.true.) then 
            print*,'PSD: error in mtx'
            print*,'PSD: any(isnan(amx3)),any(isnan(ymx3))'
            print*,any(isnan(amx3)),any(isnan(ymx3))

            if (any(isnan(ymx3))) then 
                do iz = 1, nz
                    if (isnan(ymx3(iz))) then 
                        print*,'NAN is here...',ips,iz
                    endif
                enddo 
            endif


            if (any(isnan(amx3))) then 
                do ie = 1,(nz)
                    do ie2 = 1,(nz)
                        if (isnan(amx3(ie,ie2))) then 
                            print*,'PSD: NAN is here...',ips,ie,ie2
                        endif
                    enddo
                enddo
            endif
            stop
            
        endif
    
        call DGESV(Nz,int(1),amx3,Nz,IPIV3,ymx3,Nz,INFO) 
    
        if (any(isnan(ymx3)) .or. info/=0 ) then
            print*,'PSD: error in soultion',any(isnan(ymx3)),info
            flgback = .true.
            ! pause
            exit
        endif
    
        do iz = 1, nz
            
            row =  iz   

            if (isnan(ymx3(row))) then 
                print *,'PSD: nan at', iz,ips
                stop
            endif
            
            emx3_loc(row) = dps(ips)*psdx(ips,iz)*exp(ymx3(row)) - dps(ips)*psdx(ips,iz)
            
            if ((.not.isnan(ymx3(row))).and.ymx3(row) >threshold) then 
                psdx(ips,iz) = psdx(ips,iz)*corr
            else if (ymx3(row) < -threshold) then 
                psdx(ips,iz) = psdx(ips,iz)/corr
            else   
                psdx(ips,iz) = psdx(ips,iz)*exp(ymx3(row))
            endif
        enddo 

        if (all(fact_tol == 1d0)) then 
            emx3(ips) = maxval(exp(abs(ymx3))) - 1.0d0
        else 
            emx3(ips) = maxval(abs(emx3_loc))
        endif 
    
    enddo 
    
    ! error = maxval(emx3)
    error = maxval(emx3/fact_tol)
    
    ! if (isnan(error)) error = 1d4

    if ( isnan(error) .or. any(isnan(psdx)) ) then 
        error = 1d3
        print*, 'PSD: !! error is NaN; values are returned to those before iteration with reducing dt'
        print*, 'PSD: isnan(error), info/=0,any(isnan(pdsx))'
        print*, isnan(error), any(isnan(psdx)) 
        
        flgback = .true.
        stop
        exit
    endif

    print '(a,E11.3,a,i0,a,E11.3)', 'PSD: iteration error = ',error, ', iteration = ',iter,', time step [yr] = ',dt
    iter = iter + 1 
    
    if (iter > iter_Max ) then
    ! if (iter > iter_Max .or. (method_precalc .and. error > infinity)) then
        ! dt = dt/1.01d0
        ! dt = dt/10d0
        if (dt==0d0) then 
            print *, 'dt==0d0; stop'
        
! #ifdef errmtx_printout
            ! open(unit=11,file='amx.txt',status = 'replace')
            ! open(unit=12,file='ymx.txt',status = 'replace')
            ! do ie = 1,nsp3*(nz)
                ! write(11,*) (amx3(ie,ie2),ie2 = 1,nsp3*nz)
                ! write(12,*) ymx3(ie)
            ! enddo 
            ! close(11)
            ! close(12)      
! #endif 
            stop
        endif 
        flgback = .true.
        
        exit 
    end if
    
    if (flgback) exit

enddo 

! calculating flux 
flx_psd = 0d0
do ips = 1, nps
    
    do iz = 1, nz
    
        row =  iz   
        
        vol  = 4d0/3d0*pi*(10d0**ps(ips))**3d0
        surf = 4d0*pi*(10d0**ps(ips))**2d0
                
        m_tmp = vol * psdx(ips,iz) * dps(ips)
        mprev_tmp = vol * psd(ips,iz) * dps(ips)        
        ! rxn_tmp = vol * psdx(ips,iz)*dps(ips) &
            ! & * surf * psdx(ips,iz)*dps(ips) * kpsd(iz) 
        ! rxn_tmp = surf * psdx(ips,iz)*dps(ips) * kpsd(iz) 
        rxn_tmp =  - vol * dpsd(ips,iz) * dps(ips) / dt 
        
        msupp_tmp = vol * psd_rain(ips,iz) * dps(ips)  / dt
        
        mi_tmp = vol * psd_pr(ips) * dps(ips)
        mp_tmp = vol * psdx(ips,min(iz+1,nz)) * dps(ips)
        
        dzinv = 1d0/dz(iz)
        
        ! drxn_tmp = & 
            ! & vol * 1d0 * dps(ips) &
            ! & * surf * psdx(ips,iz) * dps(ips) * kpsd(iz) &
            ! & + vol * psdx(ips,iz) * dps(ips) &
            ! & * su
        ! drxn_tmp = surf * 1d0 * dps(ips) * kpsd(iz) 
        drxn_tmp = 0d0 
        
        w_tmp = w(iz)
        wp_tmp = w(min(nz,iz+1))

        sporo_tmp = 1d0-poro(iz)
        sporop_tmp = 1d0-poro(min(nz,iz+1))
        sporoprev_tmp = 1d0-poroprev(iz)
        
        if (iz==nz) then 
            mp_tmp = mi_tmp
            wp_tmp = w0
            sporop_tmp = 1d0- poroi
        endif 
        
        sporo_tmp = 1d0
        sporop_tmp = 1d0
        sporoprev_tmp = 1d0
        
        flx_psd(ips,itflx_psd,iz) = ( &
            & ( sporo_tmp * m_tmp - sporoprev_tmp*mprev_tmp ) * dtinv  &
            & )
        flx_psd(ips,iadv_psd,iz) = ( &
            & -( sporop_tmp * wp_tmp * mp_tmp - sporo_tmp * w_tmp * m_tmp ) * dzinv &
            & )
        flx_psd(ips,irxn_psd,iz) = ( &
            & + sporo_tmp* rxn_tmp  &
            & )
        flx_psd(ips,irain_psd,iz) = ( &
            & - sporo_tmp* msupp_tmp  &
            & )
        
        do iiz = 1, nz  
            trans_tmp = sum(trans(iiz,iz,:))/nsp_sld
            if (trans_tmp == 0d0) cycle
            
            flx_psd(ips,idif_psd,iz) = flx_psd(ips,idif_psd,iz) + ( &
                & - trans_tmp * sporo(iiz) * vol * psdx(ips,iiz) * dps(ips) &
                & )
        enddo
        
        
        flx_psd(ips,ires_psd,iz) = sum(flx_psd(ips,:,iz))
        
    enddo
enddo
    
#ifdef dispPSDiter

write(chrfmt,'(i0)') nflx_psd
chrfmt = '(a5,'//trim(adjustl(chrfmt))//'(1x,a11))'

print *
print *,' [fluxes -- PSD] '
print trim(adjustl(chrfmt)),'rad',(chrflx_psd(iflx),iflx=1,nflx_psd)

write(chrfmt,'(i0)') nflx_psd
chrfmt = '(f5.2,'//trim(adjustl(chrfmt))//'(1x,E11.3))'
do ips = 1, nps
    print trim(adjustl(chrfmt)), ps(ips), (sum(flx_psd(ips,iflx,:)*dz(:)),iflx=1,nflx_psd)
enddo 
print *

#endif     
   

        
if ( chkflx .and. dt > dt_th) then 
    flx_max_max = 0d0
    do ips = 1, nps
        flx_max = 0d0
        do iflx=1,nflx_psd 
            flx_max= max( flx_max, abs( sum(flx_psd(ips,iflx,:)*dz(:)) ) )
        enddo 
        flx_max_max = max( flx_max_max, flx_max)
    enddo 
    do ips = 1, nps
    
        if ( flx_max > flx_max_max*flx_max_tol .and. abs( sum(flx_psd(ips,ires_psd,:)*dz(:)) ) > flx_max * flx_tol ) then 
            
            print *, 'too large error in PSD flx?'
            print *, 'res, max = ', abs( sum(flx_psd(ips,ires_psd,:)*dz(:)) ), flx_max
            print *, 'res/max, target = ', abs( sum(flx_psd(ips,ires_psd,:)*dz(:)) )/flx_max, flx_tol
            
            flgback = .true.
        
        endif 
        
    enddo 
endif  
   
endsubroutine psd_implicit_all_v2

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine calc_poro( &
    & nz,nsp_sld,nflx,idif,irain &! in
    & ,flx_sld,mv,poroprev,w,poroi,w_btm,dz,tol,dt &! in
    & ,poro &! inout
    & )
implicit none 

integer,intent(in)::nz,nsp_sld,nflx,idif,irain
real(kind=8),intent(in)::poroi,w_btm,tol,dt
real(kind=8),dimension(nz),intent(in)::dz,w,poroprev
real(kind=8),dimension(nz),intent(inout)::poro
real(kind=8),dimension(nsp_sld,nflx,nz),intent(in)::flx_sld
real(kind=8),dimension(nsp_sld),intent(in)::mv
! local 
real(kind=8),dimension(nz)::DV,resi_poro
integer iz,isps,row,ie,ie2
real(kind=8) w_tmp,wp_tmp,sporo_tmp,sporop_tmp,sporoprev_tmp

real(kind=8),parameter::infinity = huge(0d0)

real(kind=8) amx3(nz,nz),ymx3(nz)
integer ipiv3(nz) 
integer info 
! 
! attempt to solve porosity under any kind of porosity - uplift rate relationship 
! based on equation:
! d(1-poro)/dt = d(1-poro)*w/dz - mv*1d-6*sum( flx_sld(mixing, dust, rxns) ) 

    
ymx3 = 0d0
amx3 = 0d0
DV = 0d0

do iz=1,nz
    do isps = 1,nsp_sld 
        DV(iz) = DV(iz) + ( flx_sld(isps, 4 + isps,iz) + flx_sld(isps, idif ,iz) + flx_sld(isps, irain ,iz) ) &
            & *mv(isps)*1d-6 
    enddo 
    
    row = iz
    
    w_tmp = w(iz)
    wp_tmp = w(min(nz,iz+1))
    sporo_tmp = 1d0-poro(iz)
    sporop_tmp = 1d0-poro(min(nz,iz+1)) 
    sporoprev_tmp = 1d0-poroprev(iz)
            
    if (iz==nz) then 
        wp_tmp = w_btm
        sporop_tmp = 1d0 - poroi
    endif 
    
    if (iz/=nz) then 
    
        ymx3(row) = ( &
            & + (1d0 - sporoprev_tmp)/dt    &
            & - ( 1d0*wp_tmp - 1d0*w_tmp)/dz(iz)  &
            & + DV(iz) &
            & )
            
        amx3(row,row) = ( &
            & + (-1d0 )/dt    &
            & - ( - (-1d0)*w_tmp)/dz(iz)  &
            & )
            
        amx3(row,row+1) = ( &
            & - ( -1d0*wp_tmp )/dz(iz)  &
            & )
        
    else 
    
        ymx3(row) = ( &
            & + (1d0 - sporoprev_tmp)/dt    &
            & - ( sporop_tmp*wp_tmp - 1d0*w_tmp)/dz(iz)  &
            & + DV(iz) &
            & )
            
        amx3(row,row) = ( &
            & + (-1d0 )/dt    &
            & - (- (-1d0)*w_tmp)/dz(iz)  &
            & )
    
    
    endif 
    
enddo 
    
ymx3=-1.0d0*ymx3

if (any(isnan(amx3)).or.any(isnan(ymx3)).or.any(amx3>infinity).or.any(ymx3>infinity)) then 
! if (.true.) then 
    print*,'porocalc: error in mtx'
    print*,'porocalc: any(isnan(amx3)),any(isnan(ymx3))'
    print*,any(isnan(amx3)),any(isnan(ymx3))

    if (any(isnan(ymx3))) then 
        do iz = 1, nz
            if (isnan(ymx3(iz))) then 
                print*,'porocalc: NAN is here...',iz
            endif
        enddo 
    endif


    if (any(isnan(amx3))) then 
        do ie = 1,(nz)
            do ie2 = 1,(nz)
                if (isnan(amx3(ie,ie2))) then 
                    print*,'porocalc: NAN is here...',ie,ie2
                endif
            enddo
        enddo
    endif
    stop
    
endif

call DGESV(Nz,int(1),amx3,Nz,IPIV3,ymx3,Nz,INFO) 

poro = ymx3

! resi_poro = 0d0

! do iz=1,nz
    
    ! w_tmp = w(iz)
    ! wp_tmp = w(min(nz,iz+1))
    ! sporo_tmp = 1d0-poro(iz)
    ! sporop_tmp = 1d0-poro(min(nz,iz+1)) 
    ! sporoprev_tmp = 1d0-poroprev(iz)
            
    ! if (iz==nz) then 
        ! wp_tmp = w_btm
        ! sporop_tmp = 1d0 - poroi
    ! endif 
    
    ! resi_poro(iz) = ( &
            ! & + (sporo_tmp - sporoprev_tmp)/dt    &
            ! & - ( sporop_tmp*wp_tmp - sporo_tmp*w_tmp)/dz(iz)  &
            ! & + DV(iz)  &
            ! & )
! enddo 

! if ( maxval(resi_poro) > tol) then 
    ! print *, 'porosity calculation is wierd!?' 
    ! print *, info
    ! print *, poro
    ! print *, resi_poro
    ! stop
! endif 
   
endsubroutine calc_poro

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine calc_uplift( &
    & nz,nsp_sld,nflx,idif,irain &! IN
    & ,iwtype &! in
    & ,flx_sld,mv,poroi,w_btm,dz,poro,poroprev,dt &! in
    & ,w &! inout
    & )
implicit none 

integer,intent(in)::nz,nsp_sld,nflx,idif,irain
integer,intent(in)::iwtype
real(kind=8),intent(in)::poroi,w_btm,dt
real(kind=8),dimension(nz),intent(in)::dz,poro,poroprev
real(kind=8),dimension(nz),intent(inout)::w
real(kind=8),dimension(nsp_sld,nflx,nz),intent(in)::flx_sld
real(kind=8),dimension(nsp_sld),intent(in)::mv
! local 
real(kind=8),dimension(nz)::DV,wsporo
integer iz,isps
integer,parameter :: iwtype_cnst = 0
integer,parameter :: iwtype_pwcnst = 1
integer,parameter :: iwtype_spwcnst = 2
integer,parameter :: iwtype_flex = 3



select case(iwtype)
    case(iwtype_cnst) ! default case with constant uplift rate
        
        w = w_btm
        
    case(iwtype_pwcnst) ! poro * w = const
        
        wsporo = w_btm*poroi
        w = wsporo/poro
        
    case(iwtype_spwcnst) ! (1 - poro) * w = const
    
        wsporo = w_btm*(1d0 - poroi)
        w = wsporo/(1d0-poro)
        
    case(iwtype_flex) ! flexible w (including const porosity)
        ! in this case, porosity is not calculated but given so equation for porosity is used to solve w instead  
        ! based on equation:
        ! d(1-poro)/dt = d(1-poro)*w/dz - mv*1d-6*sum( flx_sld(mixing, dust, rxns) ) 
        ! now porosity is cont.
        ! 0 = (1-poro)*dw/dz - mv*1d-6*sum( flx_sld(mixing, dust, rxns) ) 
        
        DV = 0d0

        do iz=1,nz
            do isps = 1,nsp_sld 
                DV(iz) = DV(iz) + ( flx_sld(isps, 4 + isps,iz) + flx_sld(isps, idif ,iz) + flx_sld(isps, irain ,iz) ) &
                    & *mv(isps)*1d-6 
            enddo 
        enddo 
        
        do iz=nz,1,-1
            ! 0d0 = (1d0 - poro(iz)) * (w(iz+1) - w(iz))/dz(iz) + DV(iz)
            ! 0d0 = (1-poro(iz)) * (w(iz+1) - w(iz)) + DV(iz)*dz(iz)
            ! 0d0 = w(iz+1) - w(iz) + DV(iz)*dz(iz)/(1d0 - poro(iz)) 
            ! w(iz) = w(iz+1)  + DV(iz)*dz(iz)/(1d0 - poro(iz)) 
            ! ... more generally ... 
            ! ( (1d0 - poro(iz)) - (1d0 - poroprev(iz)) )/dt = ( (1d0 - poro(iz+1)) * w(iz+1) - (1d0 - poro(iz)) * w(iz) )/dz(iz) + DV(iz)
            ! 0d0 = ( (1d0 - poro(iz+1)) * w(iz+1) - (1d0 - poro(iz)) * w(iz) )/dz(iz) + DV(iz) - ( (1d0 - poro(iz)) - (1d0 - poroprev(iz)) )/dt
            ! 0d0 = ( (1d0 - poro(iz+1)) * w(iz+1) - (1d0 - poro(iz)) * w(iz) ) + DV(iz)*dz(iz) - ( (1d0 - poro(iz)) - (1d0 - poroprev(iz)) )/dt*dz(iz)
            ! (1d0 - poro(iz)) * w(iz) =  (1d0 - poro(iz+1)) * w(iz+1)  + DV(iz)*dz(iz) - ( (1d0 - poro(iz)) - (1d0 - poroprev(iz)) )/dt*dz(iz)
            ! w(iz) =  (1d0 - poro(iz+1))/(1d0 - poro(iz))  * w(iz+1)  + DV(iz)*dz(iz)/(1d0 - poro(iz))  - ( 1d0 - (1d0 - poroprev(iz))/(1d0 - poro(iz)) )/dt*dz(iz)
            if (iz==nz) then 
                w(iz) = w_btm  + DV(iz)*dz(iz)/(1d0 - poro(iz)) 
                ! general version
                w(iz) =  (1d0 - poroi)/(1d0 - poro(iz))  * w_btm  &
                    & + DV(iz)*dz(iz)/(1d0 - poro(iz))  - ( 1d0 - (1d0 - poroprev(iz))/(1d0 - poro(iz)) )/dt*dz(iz)
            else
                w(iz) = w(iz+1)  + DV(iz)*dz(iz)/(1d0 - poro(iz)) 
                ! general version
                w(iz) =  (1d0 - poro(iz+1))/(1d0 - poro(iz))  * w(iz+1)  &
                    & + DV(iz)*dz(iz)/(1d0 - poro(iz))  - ( 1d0 - (1d0 - poroprev(iz))/(1d0 - poro(iz)) )/dt*dz(iz)
            endif 
        enddo 
        
    case default 
        
        w = w_btm
        
endselect 
   
endsubroutine calc_uplift

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine calcupwindscheme(  &
    up,dwn,cnr,adf & ! output 
    ,w,nz   & ! input &
    )
implicit none
integer,intent(in)::nz
real(kind=8),intent(in)::w(nz)
real(kind=8),dimension(nz),intent(out)::up,dwn,cnr,adf
real(kind=8) corrf
real(kind=8) :: cnr_save(nz)
integer iz
! copied and pasted from iMP code and modified for weathering 

! ------------ determine variables to realize advection 
!  upwind scheme 
!  up  ---- burial advection at grid i = sporo(i)*w(i)*(some conc. at i) - sporo(i-1)*w(i-1)*(some conc. at i - 1) 
!  dwn ---- burial advection at grid i = sporo(i+1)*w(i+1)*(some conc. at i+1) - sporo(i)*w(i)*(some conc. at i) 
!  cnr ---- burial advection at grid i = sporo(i+1)*w(i+1)*(some conc. at i+1) - sporo(i-1)*w(i-1)*(some conc. at i - 1) 
!  when burial rate is positive, scheme need to choose up, i.e., up = 1.  
!  when burial rate is negative, scheme need to choose dwn, i.e., dwn = 1.  
!  where burial change from positive to negative or vice versa, scheme chooses cnr, i.e., cnr = 1. for the mass balance sake 

up = 0
dwn=0
cnr =0
adf=1d0
do iz=1,nz 
    if (iz==1) then 
        if (w(iz)>=0d0 .and. w(iz+1)>=0d0) then  ! positive burial 
            up(iz) = 1
        elseif (w(iz)<=0d0 .and. w(iz+1)<=0d0) then  ! negative burial 
            dwn(iz) = 1
        else   !  where burial sign changes  
            if (.not.(w(iz)*w(iz+1) <=0d0)) then 
                print*,'error'
                stop
            endif
            cnr(iz) = 1
        endif
    elseif (iz==nz) then 
        if (w(iz)>=0d0 .and. w(iz-1)>=0d0) then
            up(iz) = 1
        elseif (w(iz)<=0d0 .and. w(iz-1)<=0d0) then
            dwn(iz) = 1
        else 
            if (.not.(w(iz)*w(iz-1) <=0d0)) then 
                print*,'error'
                stop
            endif
            cnr(iz) = 1
        endif
    else 
        ! if iz-1 and iz+1 have the same sign, then it can be assigned either as up or dwn
        ! else cnr whose neighbor has a different sign 
        if (w(iz) >=0d0) then 
            if (w(iz+1)>=0d0 .and. w(iz-1)>=0d0) then
                up(iz) = 1
            else
                cnr(iz) = 1
            endif
        else  
            if (w(iz+1)<=0d0 .and. w(iz-1)<=0d0) then
                dwn(iz) = 1
            else
                cnr(iz) = 1
            endif
        endif
    endif
enddo        

if (sum(up(:)+dwn(:)+cnr(:))/=nz) then
    print*,'error',sum(up),sum(dwn),sum(cnr)
    stop
endif

! try to make sure mass balance where advection direction changes 
! 
! case (i)
!       :           w         direction    
!     iz - 2        +             ^              w(iz-1) - w(iz-2)
!     iz - 1        +             ^              w(iz  ) - w(iz-1)
!     iz            +             ^            a[w(iz+1) - w(iz  )] + b[w(iz+1) - w(iz-1)]  
!     iz + 1        -             v            c[w(iz+1) - w(iz  )] + d[w(iz+2) - w(iz  )]
!     iz + 2        -             v              w(iz+2) - w(iz+1)
!     iz + 3        -             v              w(iz+3) - w(iz+2) 
! layers [iz] & [iz+1] must yield [w(iz+1) - w(iz  )]
! and calculated as (a+b+c)w(iz+1) - (a+c+d)w(iz  ) - b w(iz-1) + d w(iz+1) 
! thus b = d = 0 and   a + b + c = 1 and a + c + d = 1
! a and c can be arbitrary as long as satisfying a + c = 1 
! --------------------------------------------------------------------------------------------
! case (ii)
!       :           w         direction    
!     iz - 2        -             v              w(iz-2) - w(iz-3)
!     iz - 1        -             v              w(iz-1) - w(iz-2)
!     iz            -             v            a[w(iz  ) - w(iz-1)] + b[w(iz+1) - w(iz-1)]  
!     iz + 1        +             ^            c[w(iz+2) - w(iz+1)] + d[w(iz+2) - w(iz  )]
!     iz + 2        +             ^              w(iz+3) - w(iz+2)
!     iz + 3        +             ^              w(iz+4) - w(iz+3) 
! layers [iz] & [iz+1] must yield [w(iz+2) - w(iz-1)]
! and calculated as (c+d)w(iz+2) - (a+b)w(iz-1) + (a-d)w(iz  ) + (b-c)w(iz+1) 
! thus c + d = 1, a + b = 1, a - d = 0, and b - c = 0
! these can be satisfied by b = c = 1 - a and d = a and a can be arbitrary as long as 0 <= a <= 1
cnr_save = cnr
do iz=1,nz-1
    if (cnr_save(iz)==1 .and. cnr_save(iz+1)==1) then 
    ! if (cnr(iz)==1 .and. cnr(iz+1)==1) then 
        if (w(iz) < 0d0 .and. w(iz+1) >= 0d0) then
            corrf = 5d0  !  This assignment of central advection term helps conversion especially when assuming turbo2 mixing 
            cnr(iz+1)=abs(w(iz)**corrf)/(abs(w(iz+1)**corrf)+abs(w(iz)**corrf))
            cnr(iz)=abs(w(iz+1)**corrf)/(abs(w(iz+1)**corrf)+abs(w(iz)**corrf))
            dwn(iz+1)=1d0-cnr(iz+1)
            up(iz)=1d0-cnr(iz)
        endif 
    endif 
    if (cnr_save(iz)==1 .and. cnr_save(iz+1)==1) then 
    ! if (cnr(iz)==1 .and. cnr(iz+1)==1) then 
        if (w(iz)>= 0d0 .and. w(iz+1) < 0d0) then
            cnr(iz+1)=0
            cnr(iz)=0
            up(iz+1)=1
            dwn(iz)=1
            adf(iz)=abs(w(iz+1))/(abs(w(iz+1))+abs(w(iz)))
            adf(iz+1)=abs(w(iz))/(abs(w(iz+1))+abs(w(iz)))
        endif 
    endif 
enddo       

endsubroutine calcupwindscheme

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

subroutine calc_khgas_all( &
    & nz,nsp_aq_all,nsp_gas_all,nsp_gas,nsp_aq,nsp_aq_cnst,nsp_gas_cnst &
    & ,chraq_all,chrgas_all,chraq_cnst,chrgas_cnst,chraq,chrgas &
    & ,maq,mgas,maqx,mgasx,maqc,mgasc &
    & ,keqgas_h,keqaq_h,keqaq_c,keqaq_s,keqaq_no3  &
    & ,pro,prox,so4fprev,so4f &
    & ,khgas,khgasx,dkhgas_dpro,dkhgas_dso4f,dkhgas_dmaq,dkhgas_dmgas &!output
    & )
implicit none

! input 
integer,intent(in)::nz,nsp_aq_all,nsp_gas_all,nsp_gas,nsp_aq,nsp_aq_cnst,nsp_gas_cnst
character(5),dimension(nsp_aq_all),intent(in)::chraq_all
character(5),dimension(nsp_gas_all),intent(in)::chrgas_all
character(5),dimension(nsp_aq_cnst),intent(in)::chraq_cnst
character(5),dimension(nsp_gas_cnst),intent(in)::chrgas_cnst
character(5),dimension(nsp_aq),intent(in)::chraq
character(5),dimension(nsp_gas),intent(in)::chrgas
real(kind=8),dimension(nsp_aq,nz),intent(in)::maqx,maq
real(kind=8),dimension(nsp_aq_cnst,nz),intent(in)::maqc
real(kind=8),dimension(nsp_gas,nz),intent(in)::mgasx,mgas
real(kind=8),dimension(nsp_gas_cnst,nz),intent(in)::mgasc
real(kind=8),dimension(nz),intent(in)::pro,prox,so4fprev,so4f
real(kind=8),dimension(nsp_gas_all,3),intent(in)::keqgas_h
real(kind=8),dimension(nsp_aq_all,4),intent(in)::keqaq_h
real(kind=8),dimension(nsp_aq_all,2),intent(in)::keqaq_c,keqaq_s,keqaq_no3
! output 
real(kind=8),dimension(nsp_gas_all,nz),intent(out)::khgas,khgasx,dkhgas_dpro,dkhgas_dso4f
real(kind=8),dimension(nsp_gas_all,nsp_gas_all,nz),intent(out)::dkhgas_dmgas
real(kind=8),dimension(nsp_gas_all,nsp_aq_all,nz),intent(out)::dkhgas_dmaq

! local 
real(kind=8),dimension(nsp_aq_all,nz)::maqx_loc,maq_loc
real(kind=8),dimension(nsp_aq_all,nz)::maqf_loc,maqf_loc_prev
real(kind=8),dimension(nsp_gas_all,nz)::mgasx_loc,mgas_loc
real(kind=8),dimension(nsp_aq_all,nz)::dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2

integer ieqgas_h0,ieqgas_h1,ieqgas_h2
data ieqgas_h0,ieqgas_h1,ieqgas_h2/1,2,3/

integer ispg,ispa,ispa_c,ipco2,ipnh3,io2,in2o

real(kind=8) kco2,k1,k2,knh3,k1nh3,kho,kn2o




ipco2 = findloc(chrgas_all,'pco2',dim=1)
ipnh3 = findloc(chrgas_all,'pnh3',dim=1)
io2 = findloc(chrgas_all,'po2',dim=1)
in2o = findloc(chrgas_all,'pn2o',dim=1)

kco2 = keqgas_h(ipco2,ieqgas_h0)
k1 = keqgas_h(ipco2,ieqgas_h1)
k2 = keqgas_h(ipco2,ieqgas_h2)

knh3 = keqgas_h(ipnh3,ieqgas_h0)
k1nh3 = keqgas_h(ipnh3,ieqgas_h1)

kho = keqgas_h(io2,ieqgas_h0)

kn2o = keqgas_h(in2o,ieqgas_h0)

khgas = 0d0
khgasx = 0d0

dkhgas_dpro = 0d0
dkhgas_dso4f = 0d0
dkhgas_dmgas = 0d0
dkhgas_dmaq = 0d0

do ispg = 1, nsp_gas_all
    select case (trim(adjustl(chrgas_all(ispg))))
        case('pco2')
            khgas(ispg,:) = kco2*(1d0+k1/pro + k1*k2/pro/pro) ! previous value; should not change through iterations 
            khgasx(ispg,:) = kco2*(1d0+k1/prox + k1*k2/prox/prox)
            
            dkhgas_dpro(ispg,:) = kco2*(k1*(-1d0)/prox**2d0 + k1*k2*(-2d0)/prox**3d0)
            
            ! obtain previous data 
            call get_maqgasx_all( &
                & nz,nsp_aq_all,nsp_gas_all,nsp_aq,nsp_gas,nsp_aq_cnst,nsp_gas_cnst &
                & ,chraq,chraq_all,chraq_cnst,chrgas,chrgas_all,chrgas_cnst &
                & ,maq,mgas,maqc,mgasc &
                & ,maq_loc,mgas_loc  &! output
                & )
            call get_maqf_all( &
                & nz,nsp_aq_all,nsp_gas_all &
                & ,chraq_all,chrgas_all &
                & ,keqgas_h,keqaq_h,keqaq_c,keqaq_s,keqaq_no3 &
                & ,mgas_loc,maq_loc,pro,so4fprev &
                & ,dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2 &! output
                & ,maqf_loc_prev  &! output
                & )
                
                
            call get_maqgasx_all( &
                & nz,nsp_aq_all,nsp_gas_all,nsp_aq,nsp_gas,nsp_aq_cnst,nsp_gas_cnst &
                & ,chraq,chraq_all,chraq_cnst,chrgas,chrgas_all,chrgas_cnst &
                & ,maqx,mgasx,maqc,mgasc &
                & ,maqx_loc,mgasx_loc  &! output
                & )
            ! getting free maq
            call get_maqf_all( &
                & nz,nsp_aq_all,nsp_gas_all &
                & ,chraq_all,chrgas_all &
                & ,keqgas_h,keqaq_h,keqaq_c,keqaq_s,keqaq_no3 &
                & ,mgasx_loc,maqx_loc,prox,so4f &
                & ,dmaqf_dpro,dmaqf_dso4f,dmaqf_dmaq,dmaqf_dpco2 &! output
                & ,maqf_loc  &! output
                & )
                
            ! account for species associated with CO3-- (ispa_c =1) and HCO3- (ispa_c =2)
            do ispa = 1, nsp_aq_all
                do ispa_c = 1,2
                    if ( keqaq_c(ispa,ispa_c) > 0d0) then 
                        if (ispa_c == 1) then ! with CO3--
                            khgas(ispg,:) = khgas(ispg,:) + ( &
                                & + keqaq_c(ispa,ispa_c)*maqf_loc_prev(ispa,:)*k1*k2*kco2*pro**(-2d0) &
                                & )
                            khgasx(ispg,:) = khgasx(ispg,:) + ( &
                                & + keqaq_c(ispa,ispa_c)*maqf_loc(ispa,:)*k1*k2*kco2*prox**(-2d0) &
                                & )
                            dkhgas_dpro(ispg,:) = dkhgas_dpro(ispg,:) + ( &
                                & + keqaq_c(ispa,ispa_c)*maqf_loc(ispa,:)*k1*k2*kco2*(-2d0)*prox**(-3d0) &
                                & + keqaq_c(ispa,ispa_c)*k1*k2*kco2*prox**(-2d0) &
                                & *dmaqf_dpro(ispa,:) &
                                & )
                            dkhgas_dso4f(ispg,:) = dkhgas_dso4f(ispg,:) + ( &
                                & + keqaq_c(ispa,ispa_c)*k1*k2*kco2*prox**(-2d0) &
                                & *dmaqf_dso4f(ispa,:) &
                                & )
                            dkhgas_dmgas(ispg,ipco2,:) = dkhgas_dmgas(ispg,ipco2,:) + ( &
                                & + keqaq_c(ispa,ispa_c)*k1*k2*kco2*prox**(-2d0) &
                                & *dmaqf_dpco2(ispa,:) &
                                & )
                            dkhgas_dmaq(ispg,ispa,:) = dkhgas_dmaq(ispg,ispa,:) + ( &
                                & + keqaq_c(ispa,ispa_c)*k1*k2*kco2*prox**(-2d0) &
                                & *dmaqf_dmaq(ispa,:) &
                                & )
                        elseif (ispa_c == 2) then ! with HCO3-
                            khgas(ispg,:) = khgas(ispg,:) + ( &
                                & + keqaq_c(ispa,ispa_c)*maqf_loc_prev(ispa,:)*k1*k2*kco2*pro**(-1d0) & 
                                & )
                            khgasx(ispg,:) = khgasx(ispg,:) + ( &
                                & + keqaq_c(ispa,ispa_c)*maqf_loc(ispa,:)*k1*k2*kco2*prox**(-1d0) & 
                                & )
                            dkhgas_dpro(ispg,:) = dkhgas_dpro(ispg,:) + ( &
                                & + keqaq_c(ispa,ispa_c)*maqf_loc(ispa,:)*k1*k2*kco2*(-1d0)*prox**(-2d0) & 
                                & + keqaq_c(ispa,ispa_c)*k1*k2*kco2*prox**(-1d0) & 
                                & *dmaqf_dpro(ispa,:) &
                                & )
                            dkhgas_dso4f(ispg,:) = dkhgas_dso4f(ispg,:) + ( &
                                & + keqaq_c(ispa,ispa_c)*k1*k2*kco2*prox**(-1d0) & 
                                & *dmaqf_dso4f(ispa,:) &
                                & )
                            dkhgas_dmgas(ispg,ipco2,:) = dkhgas_dmgas(ispg,ipco2,:) + ( &
                                & + keqaq_c(ispa,ispa_c)*k1*k2*kco2*prox**(-1d0) & 
                                & *dmaqf_dpco2(ispa,:) &
                                & )
                            dkhgas_dmaq(ispg,ispa,:) = dkhgas_dmaq(ispg,ispa,:) + ( &
                                & + keqaq_c(ispa,ispa_c)*k1*k2*kco2*prox**(-1d0) & 
                                & *dmaqf_dmaq(ispa,:) &
                                & )
                        endif 
                    endif 
                enddo 
            enddo 
            
        case('po2')
            khgas(ispg,:) = kho ! previous value; should not change through iterations 
            khgasx(ispg,:) = kho

        case('pnh3')
            khgas(ispg,:) = knh3*(1d0+pro/k1nh3) ! previous value; should not change through iterations 
            khgasx(ispg,:) = knh3*(1d0+prox/k1nh3)

            dkhgas_dpro(ispg,:) = knh3*(1d0/k1nh3)
        case('pn2o')
            khgas(ispg,:) = kn2o ! previous value; should not change through iterations 
            khgasx(ispg,:) = kn2o
    endselect 

enddo 


endsubroutine calc_khgas_all

!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
!xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

!ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
function k_arrhenius(kref,tempkref,tempk,eapp,rg)
implicit none
real(kind=8) k_arrhenius,kref,tempkref,tempk,eapp,rg
k_arrhenius = kref*exp(-eapp/rg*(1d0/tempk-1d0/tempkref))
endfunction k_arrhenius
!ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff

#ifdef no_intr_findloc
!ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
function findloc(chrlist_in,chrspecific,dim)
implicit none
character(*),intent(in)::chrlist_in(:),chrspecific
integer,intent(in)::dim
integer findloc,i

findloc = 0
do i=1, size(chrlist_in,dim=dim)
    if (trim(adjustl(chrspecific)) == trim(adjustl(chrlist_in(i)))) then
        findloc = i
        return
    endif 

enddo 

endfunction findloc
!ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
#endif 

endprogram weathering