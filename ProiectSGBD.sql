-- Proiect SGBD
-- Gestiunea unei scoli

--  6. Sa se selecteze bursele sociale a caror suma este mai mare decat media tuturor burselor sociale. Pentru toti elevii care 
-- beneficiaza de o astfel de bursa, daca sufera de o conditie medicala sa li se afiseze numele, prenumele si clasa din care fac 
-- parte. Se vor afisa o singura data tipul de bursa si suma corespunzatoare, iar apoi bursierii. Daca nu sunt elevi se va afisa 
-- 'nu exista bursieri'.

create or replace procedure f1_burseSociale
    is 
        type t_burse is 
            table of bursa_sociala % rowtype
        index by pls_integer;
        v_burse t_burse;
        
        type t_elevi is 
            varray(1000) of elev % rowtype;
        v_elevi t_elevi;
        
        nivel clasa.an % type;
        litera clasa.litera % type;
        
        suma number := 0;
        numarElevi number := 0;

begin
    select bs.*
    bulk collect into v_burse
    from bursa_sociala bs, bursa b
    where b.id_bursa = bs.id_social
    and b.suma > (select avg(b2.suma)
                  from bursa b2, bursa_sociala bs2
                  where b2.id_bursa = bs2.id_social);
                  
    select e.*
    bulk collect into v_elevi
    from elev e
    where e.conditie_medicala = 1;
    
    if v_burse.count > 0 then
        if v_elevi.count - 1000 > 0 then
            for k in 0..v_elevi.count - 1000 loop
                v_elevi.extend;
            end loop;
        end if;
        for i in v_burse.first .. v_burse.last loop
            select b.suma 
            into suma
            from bursa b
            where b.id_bursa = v_burse(i).id_social;
        
            dbms_output.put_line('Id bursa: ' || v_burse(i).id_social || ', suma: ' || suma);
            for j in v_elevi.first .. v_elevi.last loop
                if v_elevi(j).id_bursa = v_burse(i).id_social then
                    numarElevi := numarElevi + 1;
                    
                    select an, litera 
                    into nivel, litera
                    from clasa 
                    where v_elevi(j).id_clasa = clasa.id_clasa;
                        
                    dbms_output.put_line(rpad(v_elevi(j).nume || ' ' || v_elevi(j).prenume, 30) || ' ' || nivel || litera);
                end if;
            end loop;
            
            if numarElevi = 0 then
                dbms_output.put_line('Nu exista bursieri');
            end if;
            dbms_output.put_line('----------------------------------------------');
        end loop;
    end if;
end;
/

exec f1_burseSociale;
    
--  7. Sa se afiseze profesorul (nume, prenume) care preda la cele mai multe clase si care preda la o anumita clasa si elevii 
-- care il au profesor care au obtinut premii la olimpiadele nationale (vor fi afisati in ordine crescatoare. Daca au acelasi 
-- premiu vor fi pe acelasi loc).  
-- Sa se afiseze pentru un anumit interval de nivele de studiu dat ca parametru profesorul (nume, prenume) care 
-- preda la cele mai multe clase. Pentru acesta sa se afiseze in ordine crescatoare dupa clasa elevii (nr matricol, nume, 
-- prenume, clasa) care fac parte din clasele la care preda si care au fost pe podium la olimpiadele scolare.

-- ? Un cursor profesor care sa aiba parametru clasa, iar acesta sa aiba un alt cursor cu elevii care au obtinut premii la
-- olimpiada nationala. Elevii vor fi sortati din cursor. Vedem profesorii care predau la clasa a 12-a C (aici intervine partea 
-- de cursor parametrizat) si care au cele mai multe clase repartizate si afisam toti elevii din clasa respectiva care au obtinut 
-- premii la olimpiade.
-- ? Un cursor profesor pentru care trebuie sa vedem care preda la cele mai multe clase. Parametrul va fi folosit aici. Elevii 
-- sunt din acel nivel de studiu, chiar daca sunt si alti elevi poate care il au profesor si care nu sunt din acel an de studiu.

create or replace procedure f2_profesorNivel
    (an1 clasa.an % type, an2 clasa.an % type)
    is 
        cursor c_profesor (nivel clasa.an % type) is
            select nume, prenume, cursor (
                                    select distinct e.nr_matricol, nume, prenume, an, litera
                                    from elev e, clasa c, participa oli
                                    where e.id_clasa = c.id_clasa
                                    and oli.nr_matricol = e.nr_matricol
                                    and c.id_clasa in (select id_clasa
                                                       from preda
                                                       where cod_profesor = p.cod_profesor)
                                    and oli.premiu < 4
                                    order by an)
            from profesor p
            where p.cod_profesor in (select cod_profesor
                                    from preda, clasa
                                    where preda.id_clasa = clasa.id_clasa
                                    and clasa.an = nivel
                                    group by cod_profesor
                                    having count(*) = (select max(count(*))
                                                        from preda, clasa
                                                        where preda.id_clasa = clasa.id_clasa
                                                        and clasa.an = nivel
                                                        group by cod_profesor));
        
        type rc is ref cursor;
        v_rc rc;
        
        numeProfesor profesor.nume % type;
        prenumeProfesor profesor.prenume % type;
        
        matricolElev elev.nr_matricol % type;
        numeElev elev.nume % type;
        prenumeElev elev.prenume % type;
        anElev clasa.an % type;
        literaElev clasa.litera % type;
        
        v_nrElevi number := 0;
begin
    for i in an1 .. an2 loop
    
        dbms_output.put_line('Anul de studiu ' || i || ':');
        
        open c_profesor(i);
        
        loop
            fetch c_profesor into numeProfesor, prenumeProfesor, v_rc;
            exit when c_profesor % notfound;
            
            dbms_output.put_line('Profesor: ' || initcap(numeProfesor) || ' ' || initcap(prenumeProfesor));
            dbms_output.put_line(rpad('Nr.', 5) || ' ' || rpad('Nume', 30) || ' ' || 'Clasa');
            v_nrElevi := 0;
            loop
                fetch v_rc into matricolElev, numeElev, prenumeElev, anElev, literaElev;
                exit when v_rc % notfound;
                
                dbms_output.put_line(matricolElev || ' ' || rpad(initcap(numeElev) || ' ' || initcap(prenumeElev), 30) || ' ' || anElev || literaElev);
                v_nrElevi := v_nrElevi + 1;
            end loop;
            
            if v_nrElevi > 0 then
                dbms_output.put_line('Numar elevi: ' || v_nrElevi);           
            else
                dbms_output.put_line('Nu exista elevi premianti pe nivelul de studiu dat cu acest profesor');
            end if;
            
        end loop;
        
        close c_profesor;
        dbms_output.put_line('---------------------------');
    end loop;
end;
/

exec f2_profesorNivel(7, 12);


-- 8. Sa se returneze id-ul profesorulului care ia cel mai mic salariu si care preda o materie data ca parametru. 

create or replace function f3_idProfesori
    (v_materie materie.denumire % type)
return profesor.cod_profesor % type is 
    v_id profesor.cod_profesor % type; 
    v_exista number := 0;
begin
    select count(*)
    into v_exista
    from materie
    where upper(denumire) = upper(v_materie);
    
    if v_exista = 0 then
        raise_application_error(-20001, 'Nu exista materia data ca parametru.');
    end if;

    select distinct prof.cod_profesor
    into v_id
    from profesor prof, preda pr, materie m
    where salariu = (select min(salariu)
                    from profesor prof2, preda pr2, materie mat2
                    where prof2.cod_profesor = pr2.cod_profesor
                    and pr2.id_materie = mat2.id_materie 
                    and upper(mat2.denumire) = upper(v_materie)
                    )
    and prof.cod_profesor = pr.cod_profesor
    and pr.id_materie = m.id_materie
    and upper(m.denumire) = upper(v_materie);
    
    return v_id;
    
exception
    when no_data_found then
        raise_application_error(-20001, 'Niciun profesor nu preda materia data.');
    when too_many_rows then
        raise_application_error(-20002, 'Mai multi profesori care predau ' || v_materie || ' au salariul minim.');
    
end f3_idProfesori;
/

begin 
    dbms_output.put_line(f3_idProfesori('limba romana'));
end;
/

begin 
    dbms_output.put_line(f3_idProfesori('matematica'));
end;
/

begin 
    dbms_output.put_line(f3_idProfesori('limba germana'));
end;
/

begin 
    dbms_output.put_line(f3_idProfesori('limba latina'));
end;
/

-- ? Tabelele folosite sunt profesor, preda, materie. Trebuie mai intai sa determinam materia la care s-au luat cele mai multe
-- note maxime. Apoi, stiind materia, returnam profesorul care are cel mai mic salariu.


-- 9. Sa se afiseze banca la care are cont elevul care a realizat cele mai multe proiecte cu deadline-ul dupa o data data ca
-- parametru si care are insumat cel mai mare punctaj. Sa se trateze cazurile in care:
-- 1) Nu exista proiecte cu deadline-ul dupa data data ca parametru ?
-- 2) Nu exista elevi care sa realizeze numarul maxim de proiecte si cu punctaj maxim (un elev poate sa aiba punctaj maxim, dar 
--   cu nr. minim de proiecte sau sa realizeze un punctaj minim, dar cu numar maxim de proiecte) ?
-- 3) Sunt prea multi elevi care au punctaj maxim si au realizat un numar maxim de proiecte. ?
-- 4) Elevul are prea multe conturi. ?
-- 5) Elevul nu are cont la nicio banca. ?


create or replace procedure f4_contBancar
    (v_data realizeaza.deadline % type)
    is 
        v_exista number := 0;
        v_bancaNume banca.nume % type;
begin
    select count(*)
    into v_exista
    from realizeaza
    where deadline > v_data;
    
    if v_exista = 0 then
        raise_application_error(-20001, 'Nu exista niciun proiect cu deadline-ul dupa data data ca parametru');
    end if;
    
    v_exista := 0;
    
    select count(*)
    into v_exista
    from (select r2.nr_matricol
    from realizeaza r2, proiect p
    where p.id_proiect = r2.id_proiect
    and r2.deadline > v_data
    group by r2.nr_matricol
    having count(*) = (select max(count(*))
                     from realizeaza r3
                     where r3.deadline > v_data
                     group by r3.nr_matricol)
    and sum(nr_punctaj) = (select max(sum(nr_punctaj))
                        from realizeaza r3, proiect p2
                        where p2.id_proiect = r3.id_proiect
                        and r3.deadline > v_data
                        group by r3.nr_matricol));
                      
    if v_exista = 0 then
        raise_application_error(-20002, 'Nu exista elevi care sa obtina punctaj maxim cu numar maxim de proiecte');
    elsif v_exista > 1 then
        raise_application_error(-20003, 'Sunt prea multi elevi care au obtinut punctaj maxim cu numar maxim de proiecte');
    end if;
    
    select b.nume
    into v_bancaNume
    from banca b, cont c, elev e
    where b.id_banca = c.id_banca
    and e.nr_matricol = c.nr_matricol
    and e.nr_matricol in (select r2.nr_matricol
                          from realizeaza r2, proiect p
                          where p.id_proiect = r2.id_proiect
                          and r2.deadline > v_data
                          group by r2.nr_matricol
                          having count(*) = (select max(count(*))
                                             from realizeaza r3
                                             where r3.deadline > v_data
                                             group by r3.nr_matricol)
                          and sum(nr_punctaj) = (select max(sum(nr_punctaj))
                                                from realizeaza r3, proiect p2
                                                where p2.id_proiect = r3.id_proiect
                                                and r3.deadline > v_data
                                                group by r3.nr_matricol));
    
    dbms_output.put_line('Banca la care are deschis contul elevul este ' || v_bancaNume);
    
exception
    when no_data_found then
        raise_application_error(-20004, 'Elevul nu are cont deschis la nicio banca');
    when too_many_rows then
        raise_application_error(-20005, 'Elevul are conturi deschise la mai multe banci');
end;
/

begin
    f4_contBancar('01-01-2023');
end;
/

begin
    f4_contBancar('01-12-2022');
end;
/

begin
    f4_contBancar('01-11-2022');
end;
/
 
begin
    f4_contBancar('01-01-2022');
end;
/ 

begin
    f4_contBancar('30-12-2022');
end;
/                

begin
    f4_contBancar('29-12-2022');
end;
/

-- Exercitiul 10

-- Sa nu se permita inserarea unui profesor daca sunt mai mult de 5 profesori cu vechime mai mica de 2 ani.

create or replace trigger t5_elevStergere
    before insert on profesor
declare
    v_nrProfesori number := 0;
    v_medie number := 0;
begin
    select count(*)
    into v_nrProfesori
    from profesor
    where 2 > (select extract(year from sysdate) - extract(year from to_date(data_angajarii))
                from dual);
                
    if v_nrProfesori >= 3 then
        raise_application_error(-20000, 'Exista deja 3 profesori cu vechime mai mica de 2 ani');
    end if;
end;
/

-- declansare trigger
insert into PROFESOR values (243, 'stejar', 'tiberiu', 3360, '0760586904', sysdate);


-- Exercitiul 11

-- Sa se creeze un trigger care sa nu permita marirea salariilor profesorilor cu 15% a celor care predau la clase cu mai mult de 
-- 16 elevi daca noul salariul depaseste media celorlalte salarii


-- Sa se actualizeze salariile profesorilor cu 15% pentru aceia care ?
-- predau la clase cu mai mult de 16 de elevi ?
-- si daca au o vechime de minim 2 ani
-- doar daca vechiul salariu nu depaseste 5000 de lei. 

-- Sa se creeze un trigger care sa nu permita marirea salariilor profesorilor daca au un salariu initial mai mare de 5000 de lei,
-- daca au vechime mai mica de 2 ani sau daca predau un optional (au optional in componenta denumirii materiei).

create or replace trigger t6_profesorSalariu
    before update of salariu on profesor
    for each row
declare
    v_data number;
    v_opt number := 0;
begin
    if :old.salariu > 5000 then
        raise_application_error(-20000, 'Profesorul ' || initcap(:old.nume) || ' ' || initcap(:old.prenume) || ' are un salariu initial mai mare decat 5000 de lei.');
    end if;    
    
    select (extract(year from sysdate) - extract(year from :old.data_angajarii))
    into v_data
    from dual;
    
    if v_data < 2 then
        raise_application_error(-20001, 'Profesorul ' || initcap(:old.nume) || ' ' || initcap(:old.prenume) || ' are vechime mai mica de 2 ani.');
    end if;
        
    select count(*)
    into v_opt
    from materie m, preda pr
    where :old.cod_profesor = pr.cod_profesor
    and m.id_materie = pr.id_materie
    and lower(m.denumire) like 'optional%';
    
    if v_opt > 0 then
        raise_application_error(-20002, 'Profesorul ' || initcap(:old.nume) || ' ' || initcap(:old.prenume) || ' preda un optional.');
    end if;
end;
/

update profesor set salariu = salariu + (15 * salariu) / 100;

    
-- Exercitiul 12

create table istoric
    (utilizator varchar2(30),
    eveniment varchar2(30),
    data date);

create or replace trigger t7_erori
    after create or alter or drop or servererror on database
begin 
    if dbms_utility.format_error_stack is null then
        insert into istoric
        values (sys.login_user, sys.sysevent, sysdate);
    else
        raise_application_error(-20000, 'A aparut o eroare in timpul rularii query-urilor');
    end if;
end;
/

create table test(nr number);
alter table test add(nume varchar2(30));
drop table test;

select * from istoric;

-- Optionale

-- Exercitiul 13
create or replace package pachet_complet as
    procedure f1_burseSociale;
    procedure f2_profesorNivel (an1 clasa.an % type, an2 clasa.an % type);
    function f3_idProfesori (v_materie materie.denumire % type) return profesor.cod_profesor % type;
    procedure f4_contBancar (v_data realizeaza.deadline % type);
end;
/

create or replace package body pachet_complet as
    -- 6
    procedure f1_burseSociale
    is 
        type t_burse is 
            table of bursa_sociala % rowtype
        index by pls_integer;
        v_burse t_burse;
        
        type t_elevi is 
            varray(1000) of elev % rowtype;
        v_elevi t_elevi;
        
        nivel clasa.an % type;
        litera clasa.litera % type;
        
        suma number := 0;
        numarElevi number := 0;

    begin
        select bs.*
        bulk collect into v_burse
        from bursa_sociala bs, bursa b
        where b.id_bursa = bs.id_social
        and b.suma > (select avg(b2.suma)
                      from bursa b2, bursa_sociala bs2
                      where b2.id_bursa = bs2.id_social);
                      
        select e.*
        bulk collect into v_elevi
        from elev e
        where e.conditie_medicala = 1;
        
        if v_burse.count > 0 then
            if v_elevi.count - 1000 > 0 then
                for k in 0..v_elevi.count - 1000 loop
                    v_elevi.extend;
                end loop;
            end if;
            for i in v_burse.first .. v_burse.last loop
                select b.suma 
                into suma
                from bursa b
                where b.id_bursa = v_burse(i).id_social;
            
                dbms_output.put_line('Id bursa: ' || v_burse(i).id_social || ', suma: ' || suma);
                for j in v_elevi.first .. v_elevi.last loop
                    if v_elevi(j).id_bursa = v_burse(i).id_social then
                        numarElevi := numarElevi + 1;
                        
                        select an, litera 
                        into nivel, litera
                        from clasa 
                        where v_elevi(j).id_clasa = clasa.id_clasa;
                            
                        dbms_output.put_line(rpad(v_elevi(j).nume || ' ' || v_elevi(j).prenume, 30) || ' ' || nivel || litera);
                    end if;
                end loop;
                
                if numarElevi = 0 then
                    dbms_output.put_line('Nu exista bursieri');
                end if;
                dbms_output.put_line('----------------------------------------------');
            end loop;
        end if;
    end;
    
    -- 7

    procedure f2_profesorNivel
    (an1 clasa.an % type, an2 clasa.an % type)
    is 
        cursor c_profesor (nivel clasa.an % type) is
            select nume, prenume, cursor (
                                    select distinct e.nr_matricol, nume, prenume, an, litera
                                    from elev e, clasa c, participa oli
                                    where e.id_clasa = c.id_clasa
                                    and oli.nr_matricol = e.nr_matricol
                                    and c.id_clasa in (select id_clasa
                                                       from preda
                                                       where cod_profesor = p.cod_profesor)
                                    and oli.premiu < 4
                                    order by an)
            from profesor p
            where p.cod_profesor in (select cod_profesor
                                    from preda, clasa
                                    where preda.id_clasa = clasa.id_clasa
                                    and clasa.an = nivel
                                    group by cod_profesor
                                    having count(*) = (select max(count(*))
                                                        from preda, clasa
                                                        where preda.id_clasa = clasa.id_clasa
                                                        and clasa.an = nivel
                                                        group by cod_profesor));
        
        type rc is ref cursor;
        v_rc rc;
        
        numeProfesor profesor.nume % type;
        prenumeProfesor profesor.prenume % type;
        
        matricolElev elev.nr_matricol % type;
        numeElev elev.nume % type;
        prenumeElev elev.prenume % type;
        anElev clasa.an % type;
        literaElev clasa.litera % type;
        
        v_nrElevi number := 0;
    begin
        for i in an1 .. an2 loop
        
            dbms_output.put_line('Anul de studiu ' || i || ':');
            
            open c_profesor(i);
            
            loop
                fetch c_profesor into numeProfesor, prenumeProfesor, v_rc;
                exit when c_profesor % notfound;
                
                dbms_output.put_line('Profesor: ' || initcap(numeProfesor) || ' ' || initcap(prenumeProfesor));
                dbms_output.put_line(rpad('Nr.', 5) || ' ' || rpad('Nume', 30) || ' ' || 'Clasa');
                v_nrElevi := 0;
                loop
                    fetch v_rc into matricolElev, numeElev, prenumeElev, anElev, literaElev;
                    exit when v_rc % notfound;
                    
                    dbms_output.put_line(matricolElev || ' ' || rpad(initcap(numeElev) || ' ' || initcap(prenumeElev), 30) || ' ' || anElev || literaElev);
                    v_nrElevi := v_nrElevi + 1;
                end loop;
                
                if v_nrElevi > 0 then
                    dbms_output.put_line('Numar elevi: ' || v_nrElevi);           
                else
                    dbms_output.put_line('Nu exista elevi premianti pe nivelul de studiu dat cu acest profesor');
                end if;
                
            end loop;
            
            close c_profesor;
            dbms_output.put_line('---------------------------');
        end loop;
    end;

    -- 8
    
    function f3_idProfesori
        (v_materie materie.denumire % type)
    return profesor.cod_profesor % type is 
        v_id profesor.cod_profesor % type; 
        v_exista number := 0;
    begin
        select count(*)
        into v_exista
        from materie
        where upper(denumire) = upper(v_materie);
        
        if v_exista = 0 then
            raise_application_error(-20001, 'Nu exista materia data ca parametru.');
        end if;
    
        select distinct prof.cod_profesor
        into v_id
        from profesor prof, preda pr, materie m
        where salariu = (select min(salariu)
                        from profesor prof2, preda pr2, materie mat2
                        where prof2.cod_profesor = pr2.cod_profesor
                        and pr2.id_materie = mat2.id_materie 
                        and upper(mat2.denumire) = upper(v_materie)
                        )
        and prof.cod_profesor = pr.cod_profesor
        and pr.id_materie = m.id_materie
        and upper(m.denumire) = upper(v_materie);
        
        return v_id;
        
    exception
        when no_data_found then
            raise_application_error(-20001, 'Niciun profesor nu preda materia data.');
        when too_many_rows then
            raise_application_error(-20002, 'Mai multi profesori care predau ' || v_materie || ' au salariul minim.');
        
    end f3_idProfesori;
    
    -- 9
    
    procedure f4_contBancar
    (v_data realizeaza.deadline % type)
    is 
        v_exista number := 0;
        v_bancaNume banca.nume % type;
    begin
        select count(*)
        into v_exista
        from realizeaza
        where deadline > v_data;
        
        if v_exista = 0 then
            raise_application_error(-20001, 'Nu exista niciun proiect cu deadline-ul dupa data data ca parametru');
        end if;
        
        v_exista := 0;
        
        select count(*)
        into v_exista
        from (select r2.nr_matricol
        from realizeaza r2, proiect p
        where p.id_proiect = r2.id_proiect
        and r2.deadline > v_data
        group by r2.nr_matricol
        having count(*) = (select max(count(*))
                         from realizeaza r3
                         where r3.deadline > v_data
                         group by r3.nr_matricol)
        and sum(nr_punctaj) = (select max(sum(nr_punctaj))
                            from realizeaza r3, proiect p2
                            where p2.id_proiect = r3.id_proiect
                            and r3.deadline > v_data
                            group by r3.nr_matricol));
                          
        if v_exista = 0 then
            raise_application_error(-20002, 'Nu exista elevi care sa obtina punctaj maxim cu numar maxim de proiecte');
        elsif v_exista > 1 then
            raise_application_error(-20003, 'Sunt prea multi elevi care au obtinut punctaj maxim cu numar maxim de proiecte');
        end if;
        
        select b.nume
        into v_bancaNume
        from banca b, cont c, elev e
        where b.id_banca = c.id_banca
        and e.nr_matricol = c.nr_matricol
        and e.nr_matricol in (select r2.nr_matricol
                              from realizeaza r2, proiect p
                              where p.id_proiect = r2.id_proiect
                              and r2.deadline > v_data
                              group by r2.nr_matricol
                              having count(*) = (select max(count(*))
                                                 from realizeaza r3
                                                 where r3.deadline > v_data
                                                 group by r3.nr_matricol)
                              and sum(nr_punctaj) = (select max(sum(nr_punctaj))
                                                    from realizeaza r3, proiect p2
                                                    where p2.id_proiect = r3.id_proiect
                                                    and r3.deadline > v_data
                                                    group by r3.nr_matricol));
        
        dbms_output.put_line('Banca la care are deschis contul elevul este ' || v_bancaNume);
        
    exception
        when no_data_found then
            raise_application_error(-20004, 'Elevul nu are cont deschis la nicio banca');
        when too_many_rows then
            raise_application_error(-20005, 'Elevul are conturi deschise la mai multe banci');
    end;
end;
/

exec pachet_complet.f1_burseSociale;


-- Exercitiul 14
    -- 

    -- Un pachet care sa vina in intampinarea contabililor care se ocupa de gestiunea burselor. In functie de suma totala pe 
    -- care o are la dispozitie, contabilul va putea creste sau scade suma oferita elevilor. Daca aceasta este mai mica decat suma 
    -- minima pentru a plati cel putin circa 50 de lei fiecarui elev care ia bursa, indiferent de tipul ei, se va afisa o eroare. Cand 
    -- se modifica o bursa se va afisa noua suma. 
    create or replace package pachet_final as      
        -- proceduri
        procedure cuantumBani(v_bani number);
        procedure actualizareBurse;
        
        -- functii
        function procent(idBursa number, suma_totala number) return number;
        function diferenta(suma_initiala number, suma_modificata number) return number;
        
        -- tipuri de date
        type t_burseSociale is 
            table of bursa_sociala % rowtype
        index by pls_integer;
        
        type t_burseMerit is
            varray(100) of bursa_merit % rowtype;
        
        type t_bursePerformanta is
            table of bursa_performanta % rowtype
        index by pls_integer;
        
        -- variabile
        v_cuantum number := 0;
        
        v_burseSociale t_burseSociale;
        v_burseMerit t_burseMerit;
        v_bursePerformanta t_bursePerformanta;
        
end;
/
       
        
create or replace package body pachet_final as
    function diferenta
        (suma_initiala number, suma_modificata number)
        return number
    is
        v_diferenta number := 0;
    begin 
        if suma_modificata > suma_initiala then
            v_diferenta := ((suma_modificata - suma_initiala) / suma_initiala) * 100;
        else 
            v_diferenta := ((suma_initiala - suma_modificata) / suma_initiala) * 100;
        end if;
        
        return v_diferenta;
    end;
    
    function procent
        (idBursa number, suma_totala number)
        return number 
    is 
        v_procent number := 0;
        v_suma number := 0;
    begin 
        select suma
        into v_suma
        from bursa
        where id_bursa = idBursa;
        
        v_procent := round(v_suma * 100) / suma_totala;
        return v_procent;
    end;

    procedure cuantumBani
        (v_bani number)
        is 
            v_nrElevi number := 0;
        begin
            select count(*)
            into v_nrElevi
            from elev
            where id_bursa != null;
            
            if v_nrElevi * 50 > v_bani then
                raise_application_error(-20000, 'Cuantumul nu acopera minimul de cheltuieli pentru plata burselor.');
            else 
                v_cuantum := v_bani;
                
                select b.*
                bulk collect into v_burseMerit
                from bursa_merit b;
                
                select b.*
                bulk collect into v_burseSociale
                from bursa_sociala b;
                
                select b.*
                bulk collect into v_bursePerformanta
                from bursa_performanta b;
                
                actualizareBurse;
            end if;
        end;
        
    procedure actualizareBurse
        is
            v_procent_social number := 0;
            v_suma_social number := 0;
            
            v_procent_merit number := 0;
            v_suma_merit number := 0;
            
            v_procent_performanta number := 0;
            v_suma_performanta number := 0;
            
            v_diferenta number := 0;
            v_suma number := 0;
            v_suma_totala number := 0;
        begin
            select sum(b.suma)
            into v_suma_totala
            from bursa b, elev e
            where b.id_bursa = e.id_bursa (+);
            
            dbms_output.put_line(v_suma_totala);
            if v_suma_totala = v_cuantum then
                dbms_output.put_line('Cuantumul este suficient pentru a plati bursele elevilor. Nu este cazul de alte modificari.');
            else
                if v_suma_totala < v_cuantum then
                    dbms_output.put_line('Cuantumul este mai mare decat necesarul cu '|| diferenta(v_suma_totala, v_cuantum) || ' pentru a plati bursele. Acestea vor fi marite.');
                else
                    dbms_output.put_line('Cuantumul este mai mic decat necesarul cu '|| diferenta(v_suma_totala, v_cuantum) || ' pentru a plati bursele. Acestea vor fi micsorate.');
                end if;
                
                for i in v_burseMerit.first .. v_burseMerit.last loop
                    v_procent_merit := procent(v_burseMerit(i).id_merit, v_suma_totala);
                    
                    v_suma := round((v_cuantum * v_procent_merit) / 100);
                    
                    update bursa set suma = v_suma where id_bursa = v_burseMerit(i).id_merit;
                    dbms_output.put_line('Bursa de merit cu id-ul ' || v_burseMerit(i).id_merit || ' are noua suma ' || v_suma || 'lei');
                end loop;   
                
                for i in v_bursePerformanta.first .. v_bursePerformanta.last loop
                    v_procent_performanta := procent(v_bursePerformanta(i).id_performanta, v_suma_totala);
                    
                    v_suma := round((v_cuantum * v_procent_performanta) / 100);
                    
                    update bursa set suma = v_suma where id_bursa = v_bursePerformanta(i).id_performanta;
                    dbms_output.put_line('Bursa de performanta cu id-ul ' || v_bursePerformanta(i).id_performanta || ' are noua suma ' || v_suma || 'lei');
                end loop;
                
                for i in v_burseSociale.first .. v_burseSociale.last loop
                    v_procent_social := procent(v_burseSociale(i).id_social, v_suma_totala); 
                    
                    v_suma := round((v_cuantum * v_procent_social) / 100);
                    
                    update bursa set suma = v_suma where id_bursa = v_burseSociale(i).id_social;
                    dbms_output.put_line('Bursa sociala cu id-ul ' || v_burseSociale(i).id_social || ' are noua suma ' || v_suma || 'lei');
                end loop;
            end if;
        end;
end;
/

begin
    pachet_final.cuantumBani(250000);
end;
/

set serveroutput on;
            
-- Crearea tabelelor si introducerea datelor in acestea
create table MATERIE (
id_materie number(2, 0) not null primary key,
denumire varchar2(20) not null
);

insert into MATERIE values (1, 'matematica');
insert into MATERIE values (2, 'chimie');
insert into MATERIE values (3, 'fizica');
insert into MATERIE values (4, 'sport');
insert into MATERIE values (5, 'informatica');
insert into MATERIE values (6, 'biologie');
insert into MATERIE values (7, 'psihologie');
insert into MATERIE values (8, 'limba romana');
insert into MATERIE values (9, 'limba franceza');
insert into MATERIE values (10, 'educatie civica');
insert into MATERIE values (11, 'muzica');
insert into MATERIE values (12, 'desen');
insert into MATERIE values (13, 'limba engleza');
insert into MATERIE values (14, 'TIC');
insert into MATERIE values (15, 'istorie');
insert into MATERIE values (16, 'geografie');
insert into MATERIE values (17, 'filozofie');
insert into MATERIE values (18, 'limba spaniola');
insert into MATERIE values (19, 'educatie tehnologica');
insert into MATERIE values (20, 'Optional PopCulture');
insert into MATERIE values (21, 'limba latina');

create table PROFESOR (
cod_profesor number(4, 0) not null primary key,
nume varchar2(20) not null,
prenume varchar2(20) not null, 
salariu number(4, 0) not null, 
nr_telefon varchar2(10) not null,
data_angajarii date not null
);

insert into PROFESOR values (200, 'dima', 'cezar', 3179, '0782446817', '25-03-2003');
insert into PROFESOR values (138, 'apostol', 'daria', 4800, '0797783548', '24-04-2008');
insert into PROFESOR values (5, 'amoraritei', 'cezar', 4567, '0717474711', '01-11-1984');
insert into PROFESOR values (161, 'penescu', 'cezar', 3413, '0711761768', '10-06-1998');
insert into PROFESOR values (124, 'apostol', 'cezar', 5681, '0769904924', '19-09-2007');
insert into PROFESOR values (22, 'scutaru', 'amalia', 4313, '0736818377', '15-02-1982');
insert into PROFESOR values (194, 'cojocaru', 'delia', 3482, '0734043134', '07-04-1994');
insert into PROFESOR values (48, 'scutaru', 'stefan', 3068, '0731248667', '11-08-2012');
insert into PROFESOR values (117, 'popovici', 'matei', 6193, '0761888769', '28-02-1998');
insert into PROFESOR values (191, 'apetrei', 'calin', 5112, '0759779287', '06-08-1980');
insert into PROFESOR values (23, 'amoraritei', 'delia', 4396, '0780343570', '17-03-2018');
insert into PROFESOR values (118, 'onciuleanu', 'calin', 3131, '0715530331', '08-01-2015');
insert into PROFESOR values (137, 'cuzic', 'cezar', 4166, '0736351626', '18-08-1993');
insert into PROFESOR values (90, 'alexa', 'elias', 4939, '0714248130', '04-06-2018');
insert into PROFESOR values (61, 'apetrei', 'daria', 6181, '0752436786', '15-07-2015');
insert into PROFESOR values (173, 'popovici', 'stefana', 4691, '0738737343', '01-03-2017');
insert into PROFESOR values (129, 'amoraritei', 'robert', 5647, '0762800380', '27-11-2008');
insert into PROFESOR values (199, 'amoraritei', 'daria', 6121, '0760141077', '02-07-1995');
insert into PROFESOR values (27, 'popescu', 'delia', 4337, '0740240855', '21-03-2012');
insert into PROFESOR values (152, 'popescu', 'valentin', 5252, '0763332056', '04-12-1985');
insert into PROFESOR values (136, 'cuzic', 'elias', 5716, '0774357097', '07-08-2019');
insert into PROFESOR values (128, 'amoraritei', 'matei', 3673, '0751863354', '02-02-1987');
insert into PROFESOR values (164, 'alexa', 'valentin', 5449, '0760084349', '16-02-2010');
insert into PROFESOR values (213, 'mutu', 'ciprian', 3068, '0750000010', '17-02-2011');
insert into PROFESOR values (219, 'dita', 'constantin', 3479, '0702400817', sysdate);
insert into PROFESOR values (230, 'drelciuc', 'cristian', 3000, '0723009001', sysdate);
insert into PROFESOR values (231, 'ambrozie', 'vasile', 3240, '0760112004', sysdate);

create table CLASA (
id_clasa number(3, 0) not null primary key, 
an number(2, 0) not null, 
litera char(1) not null
);

insert into CLASA values (80, 12, 'A');
insert into CLASA values (81, 12, 'B');
insert into CLASA values (82, 12, 'C');
insert into CLASA values (83, 12, 'D');
insert into CLASA values (100, 10, 'A');
insert into CLASA values (101, 10, 'B');
insert into CLASA values (102, 10, 'C');
insert into CLASA values (103, 10, 'D');
insert into CLASA values (104, 11, 'A');
insert into CLASA values (105, 11, 'B');
insert into CLASA values (106, 11, 'C');
insert into CLASA values (107, 11, 'D');
insert into CLASA values (210, 9, 'A');
insert into CLASA values (211, 9, 'B');
insert into CLASA values (212, 9, 'C');
insert into CLASA values (213, 9, 'D');
insert into CLASA values (206, 8, 'A');
insert into CLASA values (207, 8, 'B');
insert into CLASA values (208, 8, 'C');
insert into CLASA values (209, 8, 'D');
insert into CLASA values (467, 3, 'A');
insert into CLASA values (468, 3, 'B');
insert into CLASA values (469, 3, 'C');
insert into CLASA values (470, 3, 'D');
insert into CLASA values (300, 2, 'A');
insert into CLASA values (301, 2, 'B');
insert into CLASA values (302, 2, 'C');
insert into CLASA values (303, 2, 'D');
insert into CLASA values (405, 0, 'A');
insert into CLASA values (406, 0, 'B');
insert into CLASA values (407, 0, 'C');
insert into CLASA values (408, 0, 'D');
insert into CLASA values (327, 1, 'A');
insert into CLASA values (328, 1, 'B');
insert into CLASA values (329, 1, 'C');
insert into CLASA values (330, 1, 'D');
insert into CLASA values (560, 4, 'A');
insert into CLASA values (561, 4, 'B');
insert into CLASA values (562, 4, 'C');
insert into CLASA values (563, 4, 'D');
insert into CLASA values (565, 5, 'A');
insert into CLASA values (566, 5, 'B');
insert into CLASA values (567, 5, 'C');
insert into CLASA values (568, 5, 'D');
insert into CLASA values (580, 6, 'A');
insert into CLASA values (581, 6, 'B');
insert into CLASA values (582, 6, 'C');
insert into CLASA values (583, 6, 'D');
insert into CLASA values (901, 7, 'A');
insert into CLASA values (902, 7, 'B');
insert into CLASA values (903, 7, 'C');
insert into CLASA values (904, 7, 'D');

create table ELEV (
nr_matricol number(5, 0) not null primary key,
id_clasa number(3, 0) not null,
id_bursa number(2, 0), 
nume varchar2(20) not null, 
prenume varchar2(20) not null, 
data_nasterii date not null, 
venit_parinti number(5, 0) not null,
conditie_medicala number(1, 0) not null, 
foreign key(id_clasa) references CLASA(id_clasa),
foreign key(id_bursa) references BURSA(id_bursa)
);

insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (84753, 565, 72, 'pinzaru', 'claudia', '21-12-2011', 21140, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (68559, 208, 10, 'birleanu', 'matei', '14-12-2008', 93395, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (82323, 565, 57, 'berbecariu', 'irina', '29-07-2011', 50193, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (51001, 406, 11, 'onciuleanu', 'andrei', '29-03-2016', 34350, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (75503, 206, 56, 'boamba', 'stefana', '15-08-2008', 9245, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (91860, 105, 70, 'meran', 'andreea', '05-04-2005', 15562, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (26880, 581, 74, 'apostol', 'alexandru', '16-07-2010', 8367, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (29056, 107, 10, 'boca', 'denis', '23-11-2005', 28143, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (96444, 904, 83, 'stratu', 'denis', '15-08-2009', 81516, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (79329, 565, 14, 'radu', 'teodor', '23-04-2011', 81248, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (86076, 82, 70, 'jitareanu', 'matei', '18-11-2004', 71240, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (70844, 582, 81, 'ursaciuc', 'valentina', '26-02-2010', 79813, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (24372, 469, 12, 'scutaru', 'claudia', '05-03-2013', 54934, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (64827, 106, 71, 'alexa', 'narcisa', '25-10-2005', 82845, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (37363, 206, 13, 'ursaciuc', 'denis', '11-09-2008', 13476, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (94748, 107, 74, 'mocanu', 'matei', '22-03-2005', 47514, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (76040, 103, 56, 'popescu', 'daria', '01-08-2006', 81567, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (92152, 329, 71, 'mindrescu', 'ionela', '01-04-2015', 9403, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (76010, 100, 83, 'onciuleanu', 'bianca', '01-11-2006', 5090, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (54140, 567, 11, 'dima', 'adrian', '25-07-2011', 23831, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (80441, 102, 12, 'apostol', 'constantin', '17-11-2006', 59087, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (87296, 904, 71, 'boamba', 'andrei', '16-09-2009', 24657, 0);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (22259, 406, 'cujba', 'miruna', '22-07-2016', 58934, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (96820, 562, 10, 'tibulca', 'vasile', '15-08-2012', 31928, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (52645, 407, 82, 'ursaciuc', 'constantin', '01-08-2016', 67114, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (38923, 904, 10, 'boamba', 'daria', '07-05-2009', 81830, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (68815, 563, 70, 'boca', 'constantin', '29-01-2012', 78509, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (28349, 213, 12, 'alexa', 'andreea', '11-10-2007', 34271, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (96433, 327, 12, 'basarab', 'eduard', '13-01-2015', 57721, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (42545, 212, 13, 'cujba', 'irina', '27-12-2007', 93687, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (32529, 566, 73, 'apetrei', 'antonia', '16-10-2011', 52561, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (92092, 408, 14, 'onciuleanu', 'antonia', '17-05-2016', 48859, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (34698, 566, 10, 'popescu', 'isabela', '23-01-2011', 84109, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (27639, 210, 71, 'basarab', 'bianca', '03-12-2007', 48427, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (68754, 902, 70, 'budeanu', 'vasile', '08-07-2009', 51124, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (86863, 102, 81, 'cuzic', 'ionela', '11-06-2006', 29117, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (83253, 406, 57, 'cojocaru', 'valentin', '17-05-2016', 34534, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (76878, 563, 57, 'pinzaru', 'robert', '01-01-2012', 42879, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (44926, 107, 12, 'berbecariu', 'ionela', '04-07-2005', 92036, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (20632, 100, 11, 'boca', 'miruna', '06-02-2006', 86761, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (10724, 582, 80, 'minecan', 'vasile', '18-01-2010', 52126, 0);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (62155, 105, 'minecan', 'irina', '07-01-2005', 83006, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (91508, 208, 82, 'cojocaru', 'adrian', '19-04-2008', 1503, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (41026, 566, 83, 'pinzaru', 'viviana', '29-10-2011', 10295, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (23340, 104, 10, 'tibulca', 'valentin', '22-06-2005', 12211, 1);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (34835, 407, 'mocanu', 'bianca', '03-07-2016', 1323, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (18071, 406, 74, 'penescu', 'sorin', '01-10-2016', 6111, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (27592, 568, 73, 'scutaru', 'ionela', '15-02-2011', 27546, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (43700, 563, 13, 'berbecariu', 'daria', '13-07-2012', 28864, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (59547, 209, 74, 'stratu', 'mihai', '01-10-2008', 40105, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (62599, 100, 70, 'berbecariu', 'ioana', '12-03-2006', 38916, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (50404, 562, 56, 'cujba', 'dan', '16-09-2012', 6555, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (18428, 405, 83, 'boca', 'matei', '07-08-2016', 10764, 0);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (56266, 80, 'mocanu', 'constantin', '04-05-2004', 96381, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (12918, 583, 11, 'brinzac', 'mihaela', '10-02-2010', 57208, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (96225, 567, 56, 'lungu', 'vasile', '10-05-2011', 94392, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (74896, 83, 83, 'alexa', 'cosmin', '04-04-2004', 43837, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (32993, 208, 13, 'cuzic', 'vasile', '05-10-2008', 13521, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (33193, 104, 13, 'basarab', 'viviana', '11-07-2005', 85315, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (71442, 903, 80, 'cujba', 'sorin', '19-10-2009', 59179, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (50088, 210, 81, 'boamba', 'ionela', '07-02-2007', 79285, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (46117, 207, 82, 'brinzac', 'irina', '15-09-2008', 14825, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (83409, 211, 81, 'dima', 'dan', '25-05-2007', 16609, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (53141, 583, 74, 'apostol', 'valentin', '13-10-2010', 70666, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (89636, 330, 10, 'apostol', 'eduard', '19-12-2015', 16377, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (61529, 300, 10, 'popovici', 'narcisa', '21-11-2014', 50049, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (78503, 405, 14, 'onciuleanu', 'gabriela', '22-03-2016', 57973, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (38732, 210, 14, 'onciuleanu', 'mihai', '06-08-2007', 10901, 0);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (56992, 100, 'clem', 'roland', '01-02-2006', 93052, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (19081, 207, 71, 'maftei', 'vlad', '28-04-2008', 7156, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (56592, 328, 57, 'jitareanu', 'irina', '12-06-2015', 21457, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (42496, 211, 82, 'bistriceanu', 'cosmin', '13-08-2007', 86702, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (57624, 560, 13, 'basarab', 'constantin', '21-09-2012', 15697, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (11921, 211, 13, 'stefanoaia', 'cosmin', '15-02-2007', 87366, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (65749, 83, 71, 'mindrescu', 'narcisa', '23-03-2004', 72473, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (34754, 210, 73, 'meran', 'mihaela', '17-05-2007', 53392, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (47791, 583, 81, 'boamba', 'valentina', '13-05-2010', 34099, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (90522, 105, 56, 'cujba', 'valentina', '29-01-2005', 29652, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (25531, 210, 74, 'ursaciuc', 'gabriela', '01-08-2007', 81731, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (93405, 904, 56, 'jitareanu', 'dan', '23-12-2009', 76985, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (47700, 904, 56, 'boca', 'sorin', '01-09-2009', 49921, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (14071, 213, 13, 'pinzaru', 'miruna', '01-03-2007', 86294, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (30562, 106, 74, 'radu', 'constantin', '16-04-2005', 83356, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (68919, 581, 56, 'amoraritei', 'viviana', '10-04-2010', 86339, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (28871, 208, 57, 'lungu', 'miruna', '28-09-2008', 11985, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (74618, 211, 11, 'jitareanu', 'denis', '27-06-2007', 43302, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (60640, 213, 56, 'mindrescu', 'isabela', '29-02-2007', 70861, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (62879, 407, 70, 'budeanu', 'cosmin', '01-01-2016', 31788, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (88042, 209, 74, 'apetrei', 'alexandru', '09-02-2008', 51972, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (51136, 566, 71, 'dima', 'antonia', '22-04-2011', 8992, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (19950, 561, 71, 'maftei', 'andrei', '22-06-2012', 27370, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (97600, 101, 10, 'tibulca', 'narcisa', '28-06-2006', 70069, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (73076, 562, 56, 'mindrescu', 'andreea', '18-07-2012', 46719, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (87819, 408, 72, 'scutaru', 'mihaela', '08-02-2016', 53578, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (22438, 104, 12, 'brinzac', 'narcisa', '23-04-2005', 36394, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (48660, 329, 13, 'meran', 'vasile', '15-12-2015', 65436, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (50343, 902, 12, 'scutaru', 'robert', '17-01-2009', 79454, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (60053, 102, 83, 'boca', 'vasile', '04-05-2006', 41620, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (55839, 103, 56, 'tibulca', 'andreea', '07-03-2006', 12510, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (31643, 211, 56, 'munteanu', 'vasile', '12-08-2007', 27000, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (10851, 902, 56, 'cuzic', 'valentin', '25-06-2009', 30006, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (47221, 902, 10, 'popescu', 'denis', '14-02-2009', 12758, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (58021, 212, 14, 'apetrei', 'viviana', '24-03-2007', 35876, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (70746, 302, 73, 'birleanu', 'dan', '06-08-2014', 42424, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (65572, 303, 81, 'cuzic', 'cosmin', '24-02-2014', 11425, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (43241, 329, 57, 'cujba', 'andreea', '13-02-2015', 41773, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (18140, 562, 10, 'mindrescu', 'denis', '09-09-2012', 89376, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (35746, 213, 70, 'popovici', 'mihaela', '23-07-2007', 63865, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (74002, 100, 80, 'meran', 'ioana', '20-09-2006', 43900, 0);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (19527, 300, 'cojocaru', 'valentina', '06-01-2014', 67533, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (49626, 901, 12, 'cojocaru', 'viviana', '01-11-2009', 74727, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (80436, 100, 10, 'scutaru', 'daria', '24-01-2006', 62862, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (68934, 101, 11, 'clem', 'cosmin', '07-04-2006', 59948, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (62768, 100, 14, 'munteanu', 'andreea', '17-06-2006', 19497, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (16246, 903, 70, 'basarab', 'teodor', '05-05-2009', 11873, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (33594, 568, 72, 'brinzac', 'bianca', '02-03-2011', 31613, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (35941, 565, 10, 'dima', 'constantin', '02-10-2011', 24115, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (51850, 901, 73, 'cuzic', 'miruna', '11-12-2009', 72071, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (32114, 303, 13, 'radu', 'andrei', '20-05-2014', 64871, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (43582, 207, 70, 'apetrei', 'gabriela', '18-10-2008', 97489, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (50328, 212, 82, 'minecan', 'dan', '28-02-2007', 63560, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (74919, 82, 70, 'ursaciuc', 'adrian', '06-09-2004', 69176, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (77523, 300, 14, 'popovici', 'dan', '04-12-2014', 30642, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (96507, 563, 10, 'apostol', 'narcisa', '11-08-2012', 39865, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (13841, 103, 56, 'minecan', 'denis', '27-12-2006', 20402, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (57659, 583, 13, 'lungu', 'dan', '06-11-2010', 10544, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (52026, 328, 71, 'stratu', 'miruna', '21-10-2015', 68889, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (21259, 582, 80, 'maftei', 'ioana', '10-09-2010', 56839, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (48445, 408, 10, 'maftei', 'adrian', '27-12-2016', 83459, 0);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (37064, 583, 'tibulca', 'alexandru', '07-07-2010', 12412, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (44230, 566, 57, 'stratu', 'viviana', '19-05-2011', 31175, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (18418, 209, 83, 'birleanu', 'teodor', '04-07-2008', 6899, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (69131, 901, 80, 'stefanoaia', 'stefana', '02-05-2009', 31738, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (36613, 102, 10, 'clem', 'miruna', '25-07-2006', 46812, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (79654, 904, 82, 'stefanoaia', 'miruna', '13-09-2009', 69657, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (75937, 107, 82, 'apetrei', 'miruna', '27-07-2005', 10080, 1);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (12310, 563, 'maftei', 'mihaela', '25-04-2012', 97318, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (59946, 565, 10, 'popescu', 'mihai', '05-05-2011', 61619, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (37068, 468, 80, 'stefanoaia', 'teodor', '07-08-2013', 5355, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (93311, 104, 74, 'cozorici', 'vasile', '11-01-2005', 75595, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (69484, 328, 74, 'lungu', 'claudia', '04-11-2015', 21220, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (65663, 470, 73, 'mocanu', 'ionela', '14-02-2013', 65508, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (44668, 212, 10, 'lungu', 'teodor', '14-11-2007', 94806, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (92362, 330, 71, 'meran', 'constantin', '05-04-2015', 60766, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (48514, 106, 56, 'minecan', 'teodor', '15-12-2005', 56606, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (21499, 469, 11, 'amoraritei', 'antonia', '19-08-2013', 1024, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (19024, 561, 81, 'onciuleanu', 'petruta', '11-04-2012', 16921, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (53849, 903, 80, 'brinzac', 'matei', '17-07-2009', 66063, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (13483, 567, 83, 'popescu', 'mihaela', '29-06-2011', 65037, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (39894, 563, 70, 'cozorici', 'sorin', '01-01-2012', 73329, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (93563, 102, 83, 'boca', 'antonia', '20-07-2006', 41812, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (64500, 302, 10, 'onciuleanu', 'denis', '20-09-2014', 60715, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (85915, 567, 10, 'apostol', 'adrian', '01-03-2011', 64095, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (29203, 562, 74, 'cojocaru', 'gabriela', '13-07-2012', 73390, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (49485, 902, 57, 'mindrescu', 'stefana', '03-05-2009', 67308, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (27284, 207, 70, 'radu', 'eduard', '09-10-2008', 27980, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (71488, 562, 70, 'ursaciuc', 'andrei', '26-07-2012', 94251, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (93017, 405, 83, 'dima', 'andrei', '16-09-2016', 34653, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (46134, 101, 12, 'pinzaru', 'vlad', '25-11-2006', 59800, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (53820, 301, 83, 'popescu', 'alexandru', '05-02-2014', 70621, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (24807, 408, 81, 'stefanoaia', 'daria', '04-01-2016', 18850, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (28147, 206, 12, 'apostol', 'matei', '26-11-2008', 74455, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (23302, 207, 70, 'berbecariu', 'denis', '18-06-2008', 63866, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (29375, 583, 12, 'jitareanu', 'vasile', '17-06-2010', 22209, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (27410, 83, 11, 'cozorici', 'robert', '21-09-2004', 41066, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (34006, 583, 56, 'minecan', 'roland', '25-11-2010', 20999, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (35031, 904, 70, 'budeanu', 'dan', '04-10-2009', 83534, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (28313, 80, 13, 'lungu', 'miruna', '17-06-2004', 15221, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (37724, 107, 13, 'bistriceanu', 'matei', '04-02-2005', 33533, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (13134, 562, 10, 'boca', 'andreea', '12-11-2012', 32062, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (99281, 901, 74, 'boamba', 'gabriela', '06-08-2009', 32086, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (34123, 206, 72, 'amoraritei', 'vlad', '11-07-2008', 46861, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (43924, 303, 11, 'meran', 'narcisa', '10-12-2014', 46222, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (44843, 210, 13, 'cuzic', 'andrei', '11-10-2007', 25036, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (51360, 567, 80, 'apetrei', 'mihaela', '10-11-2011', 20732, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (55082, 470, 13, 'cojocaru', 'constantin', '07-07-2013', 50471, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (10478, 102, 14, 'penescu', 'stefana', '13-12-2006', 12907, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (98527, 468, 72, 'mindrescu', 'petruta', '26-07-2013', 79903, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (57082, 566, 11, 'pinzaru', 'irina', '22-02-2011', 99716, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (41827, 207, 82, 'clem', 'andreea', '19-06-2008', 38662, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (18974, 467, 81, 'penescu', 'petruta', '20-09-2013', 20291, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (79905, 209, 82, 'boamba', 'sorin', '14-09-2008', 52046, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (65016, 566, 14, 'popovici', 'valentin', '08-02-2011', 98161, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (16576, 211, 83, 'onciuleanu', 'adrian', '12-03-2007', 54253, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (88151, 330, 74, 'jitareanu', 'roland', '01-10-2015', 60951, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (74287, 470, 80, 'scutaru', 'valentin', '13-01-2013', 35101, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (47413, 105, 74, 'mindrescu', 'ioana', '20-03-2005', 75058, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (80664, 208, 13, 'cujba', 'adrian', '07-11-2008', 55165, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (38325, 328, 12, 'birleanu', 'miruna', '28-05-2015', 98858, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (95282, 303, 12, 'amoraritei', 'claudia', '11-12-2014', 16833, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (46288, 567, 72, 'berbecariu', 'miruna', '01-12-2011', 87543, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (68183, 107, 73, 'scutaru', 'andreea', '24-05-2005', 89541, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (39027, 213, 71, 'jitareanu', 'constantin', '15-01-2007', 69353, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (85050, 903, 57, 'apostol', 'viviana', '09-10-2009', 60662, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (82470, 580, 73, 'munteanu', 'cosmin', '20-09-2010', 36909, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (49431, 327, 11, 'basarab', 'denis', '29-08-2015', 22518, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (69139, 82, 80, 'stratu', 'petruta', '15-04-2004', 95164, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (47852, 302, 72, 'minecan', 'miruna', '13-11-2014', 21985, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (11451, 562, 71, 'apostol', 'dan', '22-07-2012', 74803, 0);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (27738, 580, 'radu', 'bianca', '18-05-2010', 57526, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (33509, 103, 83, 'stratu', 'alexandru', '01-05-2006', 37463, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (72133, 566, 72, 'jitareanu', 'cosmin', '05-10-2011', 72909, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (45942, 327, 80, 'berbecariu', 'mihai', '20-05-2015', 67204, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (36047, 329, 72, 'mindrescu', 'alexandru', '06-07-2015', 95941, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (55561, 561, 82, 'popovici', 'miruna', '04-06-2012', 11332, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (98152, 300, 83, 'apetrei', 'valentina', '01-11-2014', 75247, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (42407, 80, 82, 'dima', 'miruna', '01-06-2004', 56929, 0);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (43488, 208, 'mocanu', 'miruna', '25-03-2008', 80524, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (74775, 901, 70, 'cojocaru', 'eduard', '09-02-2009', 69914, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (83301, 83, 11, 'basarab', 'sorin', '22-04-2004', 62261, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (80462, 80, 12, 'dima', 'irina', '07-02-2004', 9494, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (97936, 106, 13, 'bistriceanu', 'sorin', '04-01-2005', 27484, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (26067, 560, 73, 'ursaciuc', 'dan', '16-12-2012', 8584, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (10406, 467, 14, 'onciuleanu', 'isabela', '16-07-2013', 24375, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (60304, 83, 80, 'bistriceanu', 'stefana', '04-03-2004', 35092, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (47264, 327, 10, 'cuzic', 'viviana', '29-12-2015', 67133, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (36477, 328, 10, 'birleanu', 'cosmin', '15-06-2015', 29529, 1);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (35920, 469, 'cuzic', 'narcisa', '23-08-2013', 84771, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (68294, 470, 57, 'cozorici', 'miruna', '14-12-2013', 97186, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (44835, 102, 57, 'apostol', 'valentina', '01-05-2006', 85849, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (69065, 83, 70, 'boca', 'irina', '01-12-2004', 16890, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (38500, 103, 82, 'lungu', 'valentin', '27-08-2006', 87308, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (60814, 206, 56, 'meran', 'gabriela', '04-03-2008', 29954, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (35090, 560, 10, 'penescu', 'gabriela', '14-08-2012', 2796, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (96888, 100, 80, 'pinzaru', 'daria', '10-09-2006', 76275, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (21483, 468, 83, 'mocanu', 'dan', '02-04-2013', 87648, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (62770, 102, 57, 'cuzic', 'petruta', '17-12-2006', 59052, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (50680, 562, 70, 'dima', 'viviana', '29-08-2012', 41238, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (35939, 468, 57, 'stefanoaia', 'mihai', '20-07-2013', 42776, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (84573, 583, 13, 'popovici', 'alexandru', '19-06-2010', 71758, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (25160, 210, 81, 'clem', 'miruna', '25-02-2007', 78879, 1);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (83692, 104, 'apetrei', 'eduard', '28-06-2005', 86727, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (99021, 567, 11, 'ursaciuc', 'ioana', '04-09-2011', 50902, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (90249, 408, 13, 'dima', 'robert', '09-05-2016', 44256, 0);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (36904, 470, 'brinzac', 'claudia', '06-08-2013', 48654, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (14948, 330, 72, 'cozorici', 'eduard', '27-02-2015', 65686, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (11799, 106, 71, 'mindrescu', 'cosmin', '28-06-2005', 19116, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (96041, 211, 13, 'cozorici', 'stefana', '01-10-2007', 6145, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (76140, 302, 11, 'berbecariu', 'teodor', '26-04-2014', 29883, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (97175, 567, 82, 'stefanoaia', 'narcisa', '09-08-2011', 86116, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (32803, 83, 81, 'cujba', 'antonia', '13-09-2004', 22665, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (72494, 82, 57, 'lungu', 'valentina', '07-10-2004', 50488, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (70808, 560, 72, 'penescu', 'teodor', '14-04-2012', 12973, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (95801, 901, 81, 'amoraritei', 'adrian', '03-05-2009', 77126, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (57072, 301, 70, 'apostol', 'andreea', '01-04-2014', 76815, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (57849, 213, 72, 'bistriceanu', 'roland', '20-04-2007', 7059, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (98256, 563, 72, 'alexa', 'petruta', '21-03-2012', 30736, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (18208, 106, 14, 'dima', 'alexandru', '10-07-2005', 55174, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (12071, 209, 71, 'jitareanu', 'adrian', '01-02-2008', 54950, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (25591, 560, 81, 'mindrescu', 'bianca', '25-09-2012', 63279, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (31170, 209, 56, 'meran', 'alexandru', '18-11-2008', 39348, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (92212, 207, 11, 'apetrei', 'valentin', '22-11-2008', 33105, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (26071, 407, 10, 'boca', 'alexandru', '10-01-2016', 86163, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (67746, 301, 83, 'budeanu', 'stefana', '09-07-2014', 78977, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (63384, 904, 11, 'clem', 'robert', '02-06-2009', 43058, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (78095, 901, 81, 'cojocaru', 'vlad', '01-06-2009', 78162, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (93466, 208, 81, 'onciuleanu', 'narcisa', '08-04-2008', 50315, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (97259, 330, 82, 'tibulca', 'miruna', '11-02-2015', 83424, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (78349, 470, 56, 'bistriceanu', 'valentin', '04-04-2013', 61134, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (85502, 470, 10, 'apostol', 'irina', '18-01-2013', 72747, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (70721, 467, 11, 'meran', 'andrei', '18-08-2013', 23557, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (78019, 903, 81, 'scutaru', 'irina', '17-01-2009', 96436, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (17113, 407, 57, 'cozorici', 'adrian', '02-11-2016', 82909, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (90147, 104, 81, 'tibulca', 'stefana', '10-07-2005', 74209, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (77866, 82, 13, 'pinzaru', 'andrei', '08-01-2004', 74580, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (95377, 212, 12, 'clem', 'claudia', '11-11-2007', 62747, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (36208, 211, 73, 'popovici', 'cosmin', '01-09-2007', 33127, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (60653, 212, 13, 'basarab', 'dan', '23-08-2007', 60237, 0);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (85080, 560, 'scutaru', 'vasile', '14-02-2012', 80663, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (15868, 82, 11, 'jitareanu', 'daria', '25-03-2004', 84943, 0);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (34760, 302, 'radu', 'daria', '24-04-2014', 54351, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (16740, 467, 10, 'boamba', 'alexandru', '05-03-2013', 70687, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (54855, 901, 72, 'pinzaru', 'antonia', '24-05-2009', 75269, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (22208, 327, 74, 'alexa', 'vasile', '22-04-2015', 52543, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (21313, 301, 11, 'bistriceanu', 'vasile', '26-06-2014', 25361, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (19178, 581, 70, 'basarab', 'valentina', '07-08-2010', 63804, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (65535, 212, 73, 'pinzaru', 'andreea', '19-08-2007', 40316, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (10751, 562, 81, 'meran', 'adrian', '28-06-2012', 5271, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (86540, 406, 56, 'tibulca', 'constantin', '20-10-2016', 98897, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (76326, 104, 72, 'radu', 'alexandru', '06-01-2005', 82975, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (56957, 213, 12, 'birleanu', 'adrian', '26-09-2007', 92138, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (43366, 302, 12, 'apostol', 'gabriela', '11-02-2014', 6420, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (82314, 903, 74, 'minecan', 'ioana', '19-06-2009', 74766, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (89124, 469, 82, 'minecan', 'isabela', '19-10-2013', 67191, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (36024, 580, 73, 'lungu', 'bianca', '16-06-2010', 6372, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (24758, 567, 70, 'ursaciuc', 'viviana', '04-04-2011', 46445, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (13915, 582, 83, 'radu', 'denis', '22-04-2010', 48723, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (26683, 213, 73, 'meran', 'denis', '11-07-2007', 35256, 1);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (98711, 208, 'cujba', 'miruna', '12-11-2008', 75438, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (81565, 901, 74, 'dima', 'miruna', '27-06-2009', 26901, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (51586, 583, 72, 'dima', 'valentin', '17-09-2010', 77886, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (50025, 100, 73, 'boamba', 'adrian', '01-05-2006', 59609, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (41810, 327, 82, 'apetrei', 'constantin', '02-05-2015', 54402, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (92127, 83, 71, 'cozorici', 'antonia', '05-09-2004', 27585, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (78915, 212, 57, 'jitareanu', 'claudia', '04-12-2007', 91120, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (93371, 904, 71, 'amoraritei', 'petruta', '02-10-2009', 5999, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (92243, 302, 13, 'penescu', 'eduard', '03-12-2014', 10144, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (12057, 212, 74, 'tibulca', 'roland', '20-08-2007', 65263, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (15743, 327, 13, 'apostol', 'vasile', '29-06-2015', 41389, 0);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (97190, 102, 'cozorici', 'valentin', '24-08-2006', 37320, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (69299, 580, 14, 'penescu', 'adrian', '01-08-2010', 46102, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (64106, 303, 80, 'cujba', 'mihaela', '07-09-2014', 10315, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (30852, 302, 82, 'popovici', 'andrei', '15-12-2014', 20331, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (23655, 213, 74, 'brinzac', 'miruna', '26-07-2007', 37995, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (55046, 83, 83, 'stefanoaia', 'valentina', '25-06-2004', 34743, 0);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (20469, 301, 'amoraritei', 'dan', '23-10-2014', 22194, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (30324, 581, 12, 'radu', 'roland', '04-10-2010', 38301, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (48261, 568, 13, 'popescu', 'stefana', '01-06-2011', 78457, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (50868, 568, 83, 'radu', 'viviana', '15-04-2011', 50625, 1);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (83780, 300, 'jitareanu', 'miruna', '25-07-2014', 88530, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (89612, 405, 71, 'radu', 'miruna', '13-07-2016', 79497, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (48308, 302, 74, 'dima', 'valentina', '29-03-2014', 19798, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (60692, 565, 70, 'cozorici', 'teodor', '11-08-2011', 24821, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (70734, 82, 82, 'mindrescu', 'andrei', '24-02-2004', 4091, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (87886, 107, 57, 'bistriceanu', 'narcisa', '11-04-2005', 53658, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (84963, 213, 56, 'popovici', 'roland', '17-04-2007', 30991, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (44118, 83, 81, 'ursaciuc', 'robert', '05-02-2004', 68233, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (13044, 100, 73, 'alexa', 'sorin', '10-12-2006', 64553, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (48881, 107, 12, 'apetrei', 'andrei', '05-04-2005', 71641, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (86676, 561, 71, 'scutaru', 'valentina', '12-11-2012', 84374, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (39158, 100, 13, 'munteanu', 'narcisa', '29-04-2006', 70958, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (15023, 210, 14, 'budeanu', 'sorin', '22-12-2007', 47956, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (98716, 583, 70, 'stratu', 'narcisa', '01-09-2010', 50449, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (79291, 302, 83, 'onciuleanu', 'teodor', '17-12-2014', 80618, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (58955, 329, 83, 'cozorici', 'andreea', '19-03-2015', 43940, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (13126, 568, 12, 'apostol', 'ioana', '14-10-2011', 29209, 1);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (65141, 101, 'onciuleanu', 'constantin', '13-10-2006', 10234, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (18763, 328, 71, 'birleanu', 'mihai', '02-10-2015', 7423, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (28337, 567, 12, 'alexa', 'constantin', '16-09-2011', 38821, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (75643, 566, 56, 'meran', 'eduard', '29-12-2011', 54580, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (13081, 582, 72, 'cuzic', 'gabriela', '10-06-2010', 92612, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (87754, 301, 10, 'cuzic', 'alexandru', '24-06-2014', 41579, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (13818, 469, 80, 'bistriceanu', 'miruna', '03-09-2013', 53288, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (22837, 209, 81, 'radu', 'narcisa', '04-07-2008', 25899, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (21492, 568, 70, 'alexa', 'adrian', '27-07-2011', 58102, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (36581, 100, 12, 'minecan', 'miruna', '17-11-2006', 97443, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (81061, 100, 82, 'scutaru', 'eduard', '29-10-2006', 26030, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (18728, 300, 11, 'mindrescu', 'daria', '21-02-2014', 8218, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (61132, 560, 56, 'bistriceanu', 'isabela', '21-03-2012', 37882, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (58870, 103, 83, 'mindrescu', 'valentin', '21-06-2006', 48415, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (90937, 562, 71, 'pinzaru', 'mihai', '14-05-2012', 13637, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (97604, 567, 13, 'apetrei', 'bianca', '02-01-2011', 72013, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (90479, 561, 80, 'popovici', 'robert', '28-12-2012', 63163, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (88104, 407, 74, 'clem', 'daria', '28-02-2016', 31457, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (15065, 82, 10, 'munteanu', 'mihai', '14-12-2004', 5805, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (53078, 469, 74, 'basarab', 'vasile', '24-11-2013', 31014, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (80901, 565, 11, 'clem', 'mihai', '27-01-2011', 17135, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (24097, 405, 10, 'clem', 'stefana', '06-11-2016', 26392, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (69281, 302, 12, 'penescu', 'daria', '01-06-2014', 11718, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (52042, 562, 82, 'birleanu', 'miruna', '16-08-2012', 90373, 1);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (99113, 583, 'amoraritei', 'roland', '20-08-2010', 88099, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (54668, 562, 80, 'boca', 'eduard', '15-01-2012', 8587, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (58047, 106, 74, 'berbecariu', 'mihaela', '23-08-2005', 90125, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (42254, 581, 83, 'lungu', 'matei', '06-08-2010', 85664, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (39462, 300, 14, 'budeanu', 'petruta', '09-09-2014', 84258, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (96002, 903, 13, 'basarab', 'stefana', '24-01-2009', 36077, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (31475, 904, 81, 'cujba', 'mihai', '18-09-2009', 18042, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (77943, 583, 56, 'munteanu', 'sorin', '29-12-2010', 98581, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (25984, 105, 71, 'budeanu', 'miruna', '16-11-2005', 39213, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (54634, 208, 70, 'penescu', 'vlad', '26-01-2008', 40204, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (99707, 211, 57, 'stefanoaia', 'miruna', '13-06-2007', 94976, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (81066, 329, 56, 'minecan', 'narcisa', '13-06-2015', 74770, 1);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (79691, 83, 'maftei', 'andreea', '20-08-2004', 14273, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (87361, 566, 72, 'onciuleanu', 'miruna', '05-04-2011', 12441, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (60879, 211, 10, 'clem', 'petruta', '08-11-2007', 8534, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (15409, 301, 13, 'birleanu', 'constantin', '03-11-2014', 68664, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (29636, 300, 14, 'ursaciuc', 'sorin', '14-05-2014', 71471, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (88521, 565, 83, 'cujba', 'alexandru', '18-02-2011', 55259, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (35211, 106, 13, 'munteanu', 'mihaela', '04-05-2005', 62143, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (79118, 300, 12, 'cojocaru', 'dan', '02-06-2014', 44767, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (94467, 407, 80, 'cozorici', 'dan', '13-01-2016', 49045, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (57183, 212, 74, 'minecan', 'sorin', '06-11-2007', 22276, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (46878, 901, 56, 'clem', 'narcisa', '13-06-2009', 24564, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (90610, 301, 10, 'popovici', 'mihai', '12-07-2014', 73181, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (38719, 107, 80, 'onciuleanu', 'roland', '28-04-2005', 17979, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (91543, 300, 11, 'boca', 'bianca', '01-05-2014', 55279, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (43399, 100, 80, 'popovici', 'eduard', '02-07-2006', 34503, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (61449, 467, 71, 'munteanu', 'irina', '11-12-2013', 22641, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (85932, 301, 81, 'berbecariu', 'andreea', '28-09-2014', 58253, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (28930, 567, 10, 'stefanoaia', 'alexandru', '29-11-2011', 31623, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (46605, 469, 82, 'jitareanu', 'antonia', '12-05-2013', 7675, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (61238, 468, 71, 'lungu', 'stefana', '02-08-2013', 22925, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (73252, 328, 72, 'scutaru', 'alexandru', '01-02-2015', 54797, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (85316, 83, 74, 'popescu', 'narcisa', '20-01-2004', 75232, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (82159, 106, 74, 'popovici', 'adrian', '24-08-2005', 1694, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (86609, 405, 72, 'boca', 'andrei', '09-04-2016', 13525, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (48037, 80, 80, 'boamba', 'andreea', '02-01-2004', 82209, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (64075, 105, 71, 'apostol', 'bianca', '12-12-2005', 48969, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (46301, 467, 56, 'apostol', 'cosmin', '05-04-2013', 69726, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (30912, 470, 57, 'mocanu', 'mihaela', '04-09-2013', 86859, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (24216, 207, 56, 'clem', 'denis', '13-11-2008', 68670, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (17228, 330, 56, 'boamba', 'miruna', '09-02-2015', 86906, 1);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (71903, 469, 'onciuleanu', 'claudia', '13-04-2013', 60671, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (38339, 83, 74, 'bistriceanu', 'miruna', '01-12-2004', 46827, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (50593, 560, 56, 'radu', 'isabela', '27-04-2012', 52206, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (24150, 901, 83, 'minecan', 'daria', '19-07-2009', 88295, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (80869, 470, 83, 'stefanoaia', 'matei', '22-03-2013', 1046, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (90613, 210, 13, 'amoraritei', 'irina', '04-04-2007', 32803, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (76830, 212, 80, 'penescu', 'roland', '12-05-2007', 68734, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (46582, 208, 12, 'berbecariu', 'roland', '16-10-2008', 2933, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (81017, 561, 56, 'cojocaru', 'antonia', '22-10-2012', 70201, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (39727, 210, 80, 'tibulca', 'sorin', '12-07-2007', 17992, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (34284, 562, 74, 'munteanu', 'dan', '29-01-2012', 94687, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (95887, 105, 82, 'ursaciuc', 'andreea', '29-01-2005', 24312, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (62358, 582, 72, 'tibulca', 'gabriela', '14-11-2010', 2922, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (39900, 581, 11, 'alexa', 'andrei', '21-01-2010', 10265, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (70154, 207, 10, 'budeanu', 'ionela', '01-04-2008', 25066, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (59804, 330, 73, 'munteanu', 'vlad', '28-06-2015', 41148, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (82926, 102, 83, 'ursaciuc', 'mihaela', '28-03-2006', 91498, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (81253, 328, 81, 'berbecariu', 'alexandru', '27-02-2015', 89899, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (25937, 470, 56, 'cuzic', 'daria', '23-06-2013', 74470, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (95695, 468, 13, 'stratu', 'stefana', '15-01-2013', 34469, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (20341, 470, 14, 'stefanoaia', 'isabela', '23-12-2013', 62152, 1);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (88787, 80, 'apetrei', 'ioana', '07-07-2004', 27208, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (90232, 408, 10, 'popescu', 'constantin', '04-10-2016', 32430, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (85638, 105, 12, 'meran', 'sorin', '17-06-2005', 78158, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (10498, 102, 73, 'meran', 'viviana', '14-02-2006', 4542, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (97679, 560, 70, 'penescu', 'isabela', '10-01-2012', 36494, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (59017, 206, 12, 'minecan', 'adrian', '10-10-2008', 94158, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (13864, 80, 71, 'popescu', 'vlad', '17-08-2004', 45198, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (17021, 565, 73, 'boamba', 'valentin', '24-07-2011', 36903, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (98765, 211, 74, 'jitareanu', 'andreea', '22-12-2007', 90241, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (48741, 408, 82, 'boamba', 'bianca', '28-04-2016', 82579, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (75662, 405, 11, 'apetrei', 'vlad', '20-10-2016', 19700, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (15399, 103, 12, 'mindrescu', 'dan', '25-11-2006', 63516, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (20920, 901, 57, 'amoraritei', 'denis', '21-12-2009', 20439, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (87479, 103, 71, 'dima', 'isabela', '01-08-2006', 18326, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (24678, 468, 56, 'minecan', 'mihaela', '19-01-2013', 50481, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (91087, 300, 11, 'onciuleanu', 'viviana', '14-04-2014', 3691, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (73548, 330, 11, 'bistriceanu', 'dan', '23-12-2015', 89859, 1);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (49164, 103, 'pinzaru', 'petruta', '18-05-2006', 85346, 0);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (56497, 467, 'apostol', 'daria', '23-12-2013', 86253, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (56401, 104, 12, 'penescu', 'irina', '10-12-2005', 8774, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (24465, 103, 83, 'penescu', 'matei', '11-02-2006', 25884, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (35077, 405, 57, 'stefanoaia', 'petruta', '25-07-2016', 25529, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (97141, 904, 13, 'cujba', 'vasile', '21-12-2009', 12128, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (99029, 406, 71, 'penescu', 'ioana', '05-02-2016', 87267, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (48861, 563, 13, 'lungu', 'vlad', '28-11-2012', 84097, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (61987, 568, 11, 'maftei', 'viviana', '01-11-2011', 21857, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (67460, 82, 57, 'jitareanu', 'valentina', '09-03-2004', 6749, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (25452, 207, 71, 'stefanoaia', 'ioana', '17-02-2008', 76119, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (40223, 209, 71, 'clem', 'alexandru', '26-12-2008', 37642, 0);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (73668, 903, 'boamba', 'vlad', '01-07-2009', 13206, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (59818, 563, 71, 'radu', 'valentin', '28-03-2012', 61716, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (82047, 583, 57, 'tibulca', 'ioana', '07-08-2010', 86549, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (37738, 408, 80, 'stefanoaia', 'roland', '28-05-2016', 57425, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (90754, 301, 83, 'cojocaru', 'roland', '01-01-2014', 75409, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (97830, 211, 74, 'cujba', 'ionela', '12-06-2007', 82627, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (22402, 81, 11, 'popovici', 'teodor', '16-04-2004', 64764, 0);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (54031, 106, 'scutaru', 'adrian', '15-01-2005', 45527, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (92383, 901, 70, 'birleanu', 'andreea', '11-03-2009', 74032, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (11660, 903, 56, 'cujba', 'robert', '02-08-2009', 53639, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (99635, 102, 83, 'munteanu', 'ioana', '05-12-2006', 82518, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (18599, 101, 83, 'apetrei', 'matei', '22-02-2006', 95073, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (13872, 406, 74, 'apostol', 'roland', '27-09-2016', 71992, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (49757, 207, 56, 'scutaru', 'constantin', '18-02-2008', 47082, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (55893, 206, 81, 'brinzac', 'gabriela', '01-10-2008', 69732, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (16011, 327, 80, 'cozorici', 'denis', '10-04-2015', 87550, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (97410, 213, 70, 'maftei', 'gabriela', '06-08-2007', 96561, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (68498, 563, 82, 'onciuleanu', 'irina', '14-12-2012', 77953, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (19150, 327, 71, 'basarab', 'narcisa', '01-08-2015', 61647, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (86036, 468, 80, 'popescu', 'eduard', '27-09-2013', 6141, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (95802, 565, 83, 'dima', 'claudia', '08-11-2011', 47358, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (16372, 302, 81, 'popovici', 'valentina', '11-08-2014', 66273, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (62421, 104, 14, 'pinzaru', 'dan', '27-07-2005', 38528, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (82200, 583, 80, 'munteanu', 'gabriela', '28-02-2010', 95597, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (37289, 212, 12, 'munteanu', 'alexandru', '15-11-2007', 92740, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (77170, 104, 57, 'pinzaru', 'stefana', '19-12-2005', 38491, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (82881, 81, 12, 'minecan', 'robert', '15-02-2004', 19458, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (51688, 408, 80, 'lungu', 'petruta', '21-01-2016', 42495, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (46404, 209, 81, 'munteanu', 'andrei', '14-10-2008', 3296, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (50139, 100, 14, 'apostol', 'sorin', '21-05-2006', 68535, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (77554, 328, 56, 'lungu', 'andrei', '16-11-2015', 56555, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (53557, 405, 13, 'clem', 'matei', '05-07-2016', 98864, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (29629, 560, 83, 'stefanoaia', 'denis', '02-02-2012', 27074, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (72669, 565, 82, 'stratu', 'antonia', '15-04-2011', 92003, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (44608, 81, 82, 'mocanu', 'robert', '04-02-2004', 16273, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (91642, 563, 72, 'meran', 'valentin', '21-03-2012', 88146, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (43717, 302, 80, 'bistriceanu', 'viviana', '05-12-2014', 36648, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (32683, 209, 70, 'birleanu', 'vasile', '23-05-2008', 96551, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (63586, 469, 14, 'apetrei', 'petruta', '28-07-2013', 69297, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (32523, 328, 71, 'mocanu', 'daria', '26-09-2015', 95623, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (45618, 210, 11, 'pinzaru', 'alexandru', '26-10-2007', 85887, 0);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (90741, 406, 'meran', 'miruna', '15-06-2016', 31821, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (77730, 83, 81, 'cujba', 'denis', '19-12-2004', 14621, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (47397, 209, 73, 'berbecariu', 'miruna', '03-08-2008', 7999, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (81752, 567, 81, 'meran', 'teodor', '05-03-2011', 7743, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (38160, 581, 10, 'popescu', 'cosmin', '19-04-2010', 13917, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (27776, 103, 80, 'mindrescu', 'viviana', '24-05-2006', 14483, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (26007, 563, 74, 'penescu', 'denis', '13-06-2012', 67139, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (16982, 105, 13, 'popovici', 'daria', '23-03-2005', 4117, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (10171, 560, 11, 'alexa', 'valentina', '01-07-2012', 95517, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (16157, 470, 83, 'radu', 'petruta', '14-01-2013', 4813, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (24494, 208, 14, 'meran', 'isabela', '14-11-2008', 77167, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (60943, 563, 70, 'dima', 'mihaela', '11-12-2012', 54777, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (49470, 582, 82, 'popescu', 'bianca', '25-03-2010', 12044, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (92603, 300, 80, 'mindrescu', 'mihaela', '05-04-2014', 56116, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (84467, 468, 70, 'bistriceanu', 'daria', '20-11-2013', 39147, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (67786, 902, 73, 'meran', 'claudia', '10-11-2009', 47608, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (90063, 103, 73, 'lungu', 'ionela', '05-11-2006', 66808, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (78276, 208, 70, 'cuzic', 'irina', '25-11-2008', 39032, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (16638, 301, 56, 'budeanu', 'alexandru', '13-07-2014', 34538, 1);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (90006, 107, 'stefanoaia', 'andrei', '11-06-2005', 21182, 0);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (63399, 100, 'stratu', 'sorin', '10-11-2006', 81962, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (14115, 405, 72, 'brinzac', 'constantin', '01-12-2016', 53988, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (16442, 83, 70, 'amoraritei', 'cosmin', '11-05-2004', 70157, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (76262, 104, 14, 'amoraritei', 'eduard', '22-06-2005', 75031, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (79734, 470, 73, 'stratu', 'ioana', '01-11-2013', 4749, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (43593, 406, 13, 'birleanu', 'isabela', '07-01-2016', 49133, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (20573, 561, 82, 'alexa', 'teodor', '25-05-2012', 58425, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (79817, 567, 83, 'meran', 'vlad', '03-09-2011', 66716, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (61673, 83, 12, 'popescu', 'matei', '29-12-2004', 20766, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (20906, 106, 14, 'cozorici', 'valentina', '19-02-2005', 12378, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (72908, 328, 12, 'budeanu', 'robert', '11-10-2015', 22883, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (10619, 406, 57, 'onciuleanu', 'robert', '24-04-2016', 50568, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (99623, 100, 57, 'dima', 'daria', '05-06-2006', 72090, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (31831, 206, 11, 'brinzac', 'eduard', '26-11-2008', 56255, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (67203, 563, 13, 'stefanoaia', 'valentin', '18-08-2012', 69491, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (33406, 83, 71, 'basarab', 'vlad', '17-09-2004', 68749, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (52953, 206, 74, 'mocanu', 'andreea', '07-11-2008', 60890, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (49163, 213, 12, 'cozorici', 'ioana', '02-05-2007', 75744, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (32715, 405, 73, 'maftei', 'claudia', '11-08-2016', 7515, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (82379, 327, 10, 'alexa', 'mihaela', '25-04-2015', 98059, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (45555, 101, 56, 'amoraritei', 'mihaela', '08-02-2006', 33741, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (31265, 329, 14, 'pinzaru', 'mihaela', '26-09-2015', 77210, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (91969, 206, 72, 'alexa', 'mihai', '08-11-2008', 12514, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (83162, 80, 72, 'clem', 'vlad', '09-06-2004', 30646, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (33391, 82, 80, 'maftei', 'denis', '25-12-2004', 54306, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (62666, 106, 11, 'budeanu', 'mihaela', '24-02-2005', 71863, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (88848, 561, 56, 'lungu', 'mihaela', '17-10-2012', 16195, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (42640, 106, 56, 'berbecariu', 'sorin', '16-12-2005', 97678, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (70046, 470, 82, 'bistriceanu', 'ionela', '29-04-2013', 93657, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (90351, 902, 80, 'basarab', 'matei', '05-02-2009', 58082, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (31681, 583, 83, 'minecan', 'vlad', '02-08-2010', 57571, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (99550, 82, 12, 'dima', 'ionela', '01-08-2004', 33248, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (51117, 106, 80, 'basarab', 'adrian', '02-09-2005', 16581, 0);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (27337, 470, 'mindrescu', 'claudia', '28-10-2013', 79482, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (63300, 100, 83, 'cojocaru', 'claudia', '23-10-2006', 37951, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (46128, 903, 56, 'cozorici', 'miruna', '21-11-2009', 54975, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (97730, 107, 71, 'minecan', 'petruta', '09-10-2005', 28333, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (54620, 328, 57, 'cojocaru', 'andreea', '04-08-2015', 37548, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (20083, 469, 57, 'apostol', 'claudia', '13-03-2013', 4735, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (17765, 468, 13, 'berbecariu', 'vlad', '11-10-2013', 42220, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (64907, 328, 56, 'lungu', 'denis', '10-06-2015', 47495, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (19925, 101, 14, 'jitareanu', 'mihaela', '27-05-2006', 14091, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (61233, 568, 82, 'popovici', 'vlad', '12-01-2011', 15075, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (82060, 467, 10, 'dima', 'cosmin', '23-12-2013', 34746, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (49612, 470, 14, 'radu', 'robert', '01-09-2013', 33381, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (24141, 80, 12, 'amoraritei', 'isabela', '22-05-2004', 90675, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (79747, 101, 10, 'brinzac', 'alexandru', '06-10-2006', 34270, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (38274, 82, 14, 'bistriceanu', 'claudia', '23-10-2004', 16193, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (80562, 102, 11, 'basarab', 'miruna', '20-05-2006', 22384, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (34676, 301, 74, 'popovici', 'ionela', '14-11-2014', 27927, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (51196, 80, 73, 'jitareanu', 'viviana', '06-05-2004', 98960, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (55455, 329, 74, 'clem', 'bianca', '08-01-2015', 21804, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (89224, 101, 10, 'brinzac', 'vasile', '07-03-2006', 66986, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (60939, 904, 83, 'ursaciuc', 'daria', '21-02-2009', 5857, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (60823, 566, 71, 'maftei', 'antonia', '28-09-2011', 38795, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (36717, 103, 12, 'mocanu', 'vasile', '08-07-2006', 19204, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (35753, 303, 13, 'scutaru', 'bianca', '29-04-2014', 97066, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (75127, 303, 72, 'brinzac', 'daria', '08-12-2014', 52137, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (49855, 329, 81, 'apetrei', 'daria', '27-02-2015', 21211, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (31442, 208, 56, 'stratu', 'mihaela', '02-04-2008', 13773, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (61173, 102, 71, 'amoraritei', 'constantin', '24-09-2006', 67796, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (18350, 405, 82, 'budeanu', 'ioana', '05-03-2016', 7053, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (93299, 211, 74, 'popescu', 'andreea', '01-01-2007', 78259, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (68335, 562, 81, 'cujba', 'isabela', '15-08-2012', 37440, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (28736, 81, 81, 'budeanu', 'constantin', '18-06-2004', 41287, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (64657, 327, 72, 'meran', 'valentina', '01-08-2015', 83148, 0);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (80712, 467, 'berbecariu', 'robert', '03-01-2013', 64936, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (23222, 82, 71, 'maftei', 'stefana', '22-12-2004', 97533, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (85610, 301, 80, 'cozorici', 'gabriela', '22-12-2014', 19295, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (98656, 329, 71, 'tibulca', 'bianca', '03-05-2015', 7554, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (68646, 107, 11, 'ursaciuc', 'vasile', '03-10-2005', 49958, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (13528, 301, 10, 'lungu', 'sorin', '16-07-2014', 18155, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (89086, 212, 74, 'tibulca', 'isabela', '02-05-2007', 57642, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (11576, 901, 74, 'apostol', 'mihai', '22-01-2009', 61927, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (41363, 300, 13, 'popovici', 'ioana', '08-07-2014', 31483, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (44962, 467, 14, 'maftei', 'narcisa', '17-08-2013', 89009, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (66045, 83, 57, 'munteanu', 'ionela', '29-03-2004', 99329, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (36864, 566, 82, 'minecan', 'mihai', '26-10-2011', 56664, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (70575, 566, 80, 'radu', 'stefana', '19-05-2011', 33795, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (83338, 406, 57, 'apetrei', 'irina', '01-06-2016', 30987, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (23399, 210, 74, 'alexa', 'antonia', '21-05-2007', 51950, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (17642, 302, 11, 'cojocaru', 'ionela', '27-06-2014', 27955, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (52078, 581, 81, 'birleanu', 'gabriela', '14-09-2010', 45558, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (56178, 213, 72, 'budeanu', 'mihai', '29-10-2007', 58894, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (36870, 560, 82, 'stratu', 'valentin', '22-10-2012', 41915, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (76530, 80, 73, 'basarab', 'andrei', '26-12-2004', 91923, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (60853, 902, 13, 'stratu', 'claudia', '19-10-2009', 8368, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (34167, 470, 83, 'amoraritei', 'teodor', '23-02-2013', 83177, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (50171, 469, 10, 'dima', 'bianca', '20-05-2013', 68834, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (72960, 904, 73, 'minecan', 'ionela', '05-01-2009', 98869, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (99345, 207, 74, 'alexa', 'ionela', '01-05-2008', 35549, 1);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (94699, 208, 'bistriceanu', 'vlad', '25-09-2008', 83502, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (65127, 107, 81, 'bistriceanu', 'ioana', '27-10-2005', 66606, 0);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (67296, 582, 'berbecariu', 'narcisa', '23-03-2010', 99356, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (98357, 207, 13, 'bistriceanu', 'andrei', '13-07-2008', 55192, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (11678, 405, 12, 'popovici', 'vasile', '26-05-2016', 32467, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (77520, 302, 74, 'tibulca', 'eduard', '27-11-2014', 55058, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (90097, 102, 80, 'bistriceanu', 'constantin', '26-08-2006', 4593, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (61988, 563, 13, 'apetrei', 'teodor', '24-10-2012', 13894, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (23215, 562, 73, 'berbecariu', 'gabriela', '22-09-2012', 76161, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (45705, 407, 10, 'minecan', 'antonia', '22-10-2016', 46943, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (94560, 582, 57, 'boamba', 'viviana', '11-12-2010', 18169, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (30743, 904, 14, 'popovici', 'irina', '21-05-2009', 63986, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (11419, 565, 57, 'mindrescu', 'miruna', '26-11-2011', 75034, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (62744, 562, 83, 'budeanu', 'miruna', '04-05-2012', 72657, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (39482, 470, 81, 'cozorici', 'cosmin', '26-12-2013', 97614, 0);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (58631, 561, 'budeanu', 'irina', '11-12-2012', 7870, 1);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (39192, 303, 'apetrei', 'isabela', '22-03-2014', 3011, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (85393, 208, 74, 'penescu', 'cosmin', '02-12-2008', 35065, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (18617, 568, 56, 'brinzac', 'andrei', '23-07-2011', 87303, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (44729, 568, 83, 'minecan', 'viviana', '07-05-2011', 81802, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (44833, 408, 70, 'ursaciuc', 'petruta', '29-10-2016', 7793, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (32632, 213, 14, 'scutaru', 'isabela', '20-04-2007', 44823, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (57975, 406, 73, 'popovici', 'isabela', '02-07-2016', 6458, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (22592, 328, 12, 'apetrei', 'narcisa', '23-03-2015', 86794, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (67849, 106, 74, 'brinzac', 'ionela', '24-07-2005', 38927, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (67477, 566, 13, 'cojocaru', 'vasile', '25-03-2011', 56919, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (99666, 329, 57, 'berbecariu', 'cosmin', '29-02-2015', 38491, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (61905, 211, 74, 'cuzic', 'teodor', '12-09-2007', 51485, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (19536, 211, 10, 'basarab', 'irina', '08-05-2007', 89519, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (78329, 206, 72, 'budeanu', 'isabela', '18-03-2008', 22460, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (95385, 408, 10, 'budeanu', 'vlad', '19-03-2016', 7395, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (87506, 467, 74, 'jitareanu', 'robert', '14-10-2013', 18577, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (10222, 213, 14, 'birleanu', 'ionela', '09-06-2007', 15129, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (83193, 560, 82, 'jitareanu', 'ioana', '24-10-2012', 96123, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (25868, 82, 72, 'budeanu', 'andrei', '15-04-2004', 55245, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (39598, 581, 11, 'ursaciuc', 'miruna', '07-03-2010', 52067, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (92025, 583, 80, 'clem', 'sorin', '12-10-2010', 52128, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (30327, 561, 80, 'cuzic', 'valentina', '17-03-2012', 71592, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (52029, 904, 74, 'pinzaru', 'ionela', '01-08-2009', 43178, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (23626, 565, 82, 'stratu', 'vasile', '26-12-2011', 69566, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (88198, 330, 12, 'mocanu', 'valentin', '17-11-2015', 45210, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (62639, 561, 73, 'pinzaru', 'teodor', '13-01-2012', 48649, 0);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (37957, 327, 'minecan', 'alexandru', '21-04-2015', 24492, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (78228, 80, 81, 'apetrei', 'dan', '04-03-2004', 14279, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (83718, 560, 71, 'brinzac', 'denis', '14-06-2012', 45569, 0);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (41996, 567, 'cuzic', 'mihai', '11-12-2011', 76421, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (47349, 213, 81, 'clem', 'constantin', '05-08-2007', 43164, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (95853, 560, 10, 'brinzac', 'antonia', '05-07-2012', 98441, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (47549, 213, 10, 'cujba', 'bianca', '01-07-2007', 96616, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (31274, 583, 71, 'minecan', 'eduard', '16-04-2010', 70003, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (35923, 904, 80, 'penescu', 'viviana', '08-03-2009', 90931, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (16498, 107, 12, 'lungu', 'irina', '29-11-2005', 13526, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (21545, 903, 12, 'amoraritei', 'andrei', '24-01-2009', 85812, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (41976, 328, 72, 'scutaru', 'vlad', '08-02-2015', 11413, 1);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (50511, 561, 'cojocaru', 'matei', '25-07-2012', 21373, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (21991, 81, 81, 'amoraritei', 'bianca', '15-05-2004', 87494, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (62797, 563, 74, 'birleanu', 'alexandru', '09-09-2012', 43723, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (49733, 329, 73, 'boamba', 'claudia', '21-06-2015', 41983, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (99275, 469, 74, 'popescu', 'claudia', '07-11-2013', 62644, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (16904, 568, 14, 'budeanu', 'bianca', '01-01-2011', 17618, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (62210, 82, 74, 'alexa', 'ioana', '17-01-2004', 44158, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (29639, 103, 81, 'cojocaru', 'robert', '19-12-2006', 76425, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (18839, 582, 14, 'stratu', 'adrian', '17-12-2010', 6267, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (19212, 405, 14, 'stratu', 'dan', '26-09-2016', 35628, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (91728, 302, 74, 'stefanoaia', 'andreea', '25-08-2014', 10579, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (97444, 80, 56, 'bistriceanu', 'mihaela', '04-07-2004', 92295, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (10352, 903, 57, 'onciuleanu', 'cosmin', '14-06-2009', 86899, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (77041, 210, 10, 'cojocaru', 'petruta', '12-10-2007', 29565, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (12607, 327, 71, 'onciuleanu', 'ionela', '15-08-2015', 75693, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (65816, 903, 57, 'alexa', 'stefana', '20-09-2009', 51536, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (81845, 561, 14, 'minecan', 'andreea', '12-04-2012', 69839, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (99308, 566, 11, 'dima', 'andreea', '09-06-2011', 72879, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (80236, 107, 80, 'popescu', 'petruta', '09-10-2005', 7260, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (35393, 209, 74, 'cuzic', 'mihaela', '26-10-2008', 31829, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (81212, 302, 72, 'scutaru', 'stefana', '06-10-2014', 77957, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (46935, 101, 71, 'munteanu', 'miruna', '12-11-2006', 58324, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (64077, 101, 13, 'alexa', 'vlad', '21-02-2006', 21325, 1);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (75204, 560, 'birleanu', 'viviana', '07-12-2012', 14237, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (68896, 329, 14, 'boca', 'mihai', '22-01-2015', 50047, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (88703, 104, 56, 'brinzac', 'sorin', '17-06-2005', 24152, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (94396, 583, 72, 'alexa', 'denis', '22-04-2010', 57229, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (57131, 103, 83, 'alexa', 'alexandru', '26-04-2006', 84455, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (63459, 302, 72, 'cujba', 'narcisa', '23-03-2014', 53424, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (77977, 567, 73, 'apostol', 'petruta', '01-11-2011', 44948, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (39445, 208, 71, 'apostol', 'vlad', '18-01-2008', 70320, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (98612, 567, 11, 'mindrescu', 'eduard', '11-06-2011', 60995, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (65646, 82, 81, 'onciuleanu', 'vlad', '18-10-2004', 80576, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (50116, 81, 80, 'cuzic', 'bianca', '10-06-2004', 49790, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (19176, 562, 74, 'tibulca', 'adrian', '10-07-2012', 78141, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (17895, 902, 70, 'pinzaru', 'isabela', '01-08-2009', 74953, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (36080, 80, 72, 'cozorici', 'isabela', '27-01-2004', 9989, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (45200, 566, 82, 'clem', 'mihaela', '11-07-2011', 83877, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (35929, 582, 57, 'mocanu', 'viviana', '23-06-2010', 81081, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (76841, 407, 12, 'basarab', 'roland', '29-03-2016', 2458, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (57206, 327, 57, 'birleanu', 'vlad', '21-04-2015', 64433, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (21530, 209, 14, 'brinzac', 'cosmin', '25-01-2008', 44500, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (70728, 407, 83, 'penescu', 'mihai', '01-08-2016', 15898, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (59204, 406, 13, 'berbecariu', 'andrei', '27-06-2016', 94881, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (88150, 903, 14, 'mocanu', 'petruta', '09-10-2009', 47585, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (39931, 467, 10, 'berbecariu', 'vasile', '22-01-2013', 54822, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (46742, 581, 13, 'apetrei', 'adrian', '01-02-2010', 28481, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (22182, 208, 73, 'stefanoaia', 'adrian', '08-03-2008', 73513, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (34443, 468, 81, 'radu', 'miruna', '29-03-2013', 21988, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (39001, 301, 70, 'clem', 'irina', '25-01-2014', 67085, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (22675, 328, 13, 'minecan', 'bianca', '25-02-2015', 74145, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (81428, 468, 13, 'apetrei', 'denis', '27-10-2013', 9888, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (23249, 582, 72, 'meran', 'matei', '26-03-2010', 25406, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (65103, 206, 10, 'stefanoaia', 'claudia', '24-02-2008', 90275, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (54852, 300, 10, 'apostol', 'ionela', '02-12-2014', 29427, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (66431, 104, 70, 'scutaru', 'mihai', '18-06-2005', 97112, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (56840, 467, 80, 'alexa', 'claudia', '05-12-2013', 48991, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (71996, 406, 13, 'budeanu', 'matei', '10-05-2016', 49637, 0);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (98444, 103, 'cojocaru', 'denis', '02-12-2006', 5696, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (51144, 328, 70, 'popescu', 'miruna', '27-08-2015', 56804, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (33466, 300, 10, 'ursaciuc', 'cosmin', '07-07-2014', 45311, 1);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (93071, 469, 'maftei', 'valentina', '14-05-2013', 72526, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (98313, 80, 83, 'popescu', 'valentina', '21-09-2004', 1253, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (19274, 581, 82, 'stefanoaia', 'gabriela', '23-08-2010', 3764, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (91463, 405, 11, 'stefanoaia', 'sorin', '24-04-2016', 43663, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (52700, 82, 82, 'boamba', 'mihai', '25-02-2004', 38700, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (69300, 902, 12, 'cojocaru', 'teodor', '15-02-2009', 97501, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (12930, 901, 81, 'ursaciuc', 'bianca', '13-02-2009', 82127, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (71447, 329, 72, 'clem', 'teodor', '26-09-2015', 66953, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (70839, 206, 12, 'boca', 'miruna', '23-06-2008', 54365, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (44638, 81, 83, 'radu', 'claudia', '26-02-2004', 2345, 1);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (32932, 107, 'boamba', 'miruna', '10-09-2005', 92389, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (36123, 408, 12, 'popovici', 'bianca', '17-10-2016', 69341, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (94765, 106, 57, 'radu', 'sorin', '08-09-2005', 2682, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (87892, 300, 71, 'popovici', 'gabriela', '13-06-2014', 65496, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (90430, 561, 80, 'munteanu', 'robert', '18-10-2012', 66816, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (69298, 567, 10, 'cojocaru', 'cosmin', '04-12-2011', 26495, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (39499, 329, 56, 'apetrei', 'mihai', '08-02-2015', 78383, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (45754, 212, 81, 'brinzac', 'miruna', '09-06-2007', 24467, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (18580, 561, 80, 'cuzic', 'miruna', '09-11-2012', 39892, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (52047, 566, 83, 'ursaciuc', 'miruna', '15-03-2011', 93443, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (92384, 107, 82, 'apetrei', 'ionela', '02-03-2005', 11574, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (54270, 405, 11, 'mocanu', 'adrian', '27-07-2016', 27218, 1);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (42980, 566, 'basarab', 'andreea', '16-08-2011', 74483, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (58540, 330, 73, 'scutaru', 'denis', '11-01-2015', 8022, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (15269, 212, 80, 'cujba', 'claudia', '17-05-2007', 97573, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (50210, 211, 72, 'penescu', 'robert', '09-04-2007', 76557, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (91566, 80, 57, 'jitareanu', 'miruna', '18-04-2004', 49281, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (39639, 328, 11, 'tibulca', 'claudia', '17-08-2015', 832, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (37156, 582, 14, 'apostol', 'miruna', '29-03-2010', 83031, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (93378, 904, 74, 'popescu', 'vasile', '26-06-2009', 31781, 0);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (46821, 407, 'lungu', 'adrian', '03-07-2016', 87521, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (34008, 902, 71, 'cozorici', 'vlad', '17-05-2009', 9822, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (65744, 469, 13, 'amoraritei', 'alexandru', '20-06-2013', 82016, 0);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (59755, 81, 'stratu', 'valentina', '24-10-2004', 20600, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (37725, 406, 57, 'stefanoaia', 'irina', '10-03-2016', 47322, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (12019, 212, 57, 'dima', 'ioana', '03-07-2007', 77137, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (89489, 300, 83, 'cujba', 'roland', '09-03-2014', 28867, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (80557, 105, 83, 'penescu', 'valentin', '01-06-2005', 16392, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (58914, 329, 73, 'popescu', 'ionela', '27-08-2015', 3489, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (13200, 303, 12, 'tibulca', 'petruta', '26-01-2014', 51279, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (27022, 303, 10, 'apetrei', 'robert', '19-11-2014', 13264, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (26989, 406, 14, 'maftei', 'matei', '28-11-2016', 57782, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (24496, 469, 14, 'radu', 'ionela', '07-07-2013', 26785, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (53992, 901, 81, 'clem', 'valentin', '06-02-2009', 78558, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (68054, 210, 81, 'cuzic', 'matei', '04-12-2007', 96514, 0);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (31898, 102, 'maftei', 'robert', '02-07-2006', 89429, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (58035, 565, 83, 'radu', 'irina', '01-01-2011', 45374, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (30549, 467, 74, 'dima', 'stefana', '08-03-2013', 95036, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (61371, 106, 57, 'cuzic', 'adrian', '01-02-2005', 16403, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (96996, 82, 14, 'pinzaru', 'matei', '03-03-2004', 67328, 0);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (24529, 209, 'mindrescu', 'vlad', '28-11-2008', 2490, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (48418, 902, 56, 'birleanu', 'andrei', '19-06-2009', 88289, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (50327, 580, 14, 'birleanu', 'mihaela', '09-12-2010', 60545, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (68716, 405, 83, 'apetrei', 'andreea', '01-07-2016', 53716, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (74535, 81, 57, 'mocanu', 'andrei', '06-11-2004', 83657, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (79243, 407, 56, 'boamba', 'ioana', '12-09-2016', 75411, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (63531, 561, 70, 'stratu', 'vlad', '03-05-2012', 43029, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (27720, 407, 72, 'tibulca', 'cosmin', '09-09-2016', 90032, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (85447, 209, 82, 'apostol', 'robert', '27-12-2008', 24659, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (30497, 329, 14, 'scutaru', 'viviana', '20-10-2015', 39598, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (52379, 405, 72, 'brinzac', 'stefana', '16-08-2016', 68997, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (70793, 103, 57, 'brinzac', 'vlad', '07-11-2006', 40588, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (87780, 207, 56, 'cojocaru', 'bianca', '14-06-2008', 81759, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (68069, 469, 70, 'meran', 'mihai', '01-02-2013', 27448, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (76959, 106, 11, 'penescu', 'valentina', '13-06-2005', 76491, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (41050, 103, 11, 'cujba', 'gabriela', '01-01-2006', 43422, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (78878, 468, 80, 'pinzaru', 'ioana', '03-07-2013', 44412, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (59321, 105, 81, 'bistriceanu', 'alexandru', '01-05-2005', 72251, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (73805, 207, 83, 'munteanu', 'valentina', '11-03-2008', 48851, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (11702, 209, 56, 'berbecariu', 'antonia', '28-01-2008', 94120, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (64514, 408, 13, 'maftei', 'irina', '11-12-2016', 52556, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (71170, 206, 80, 'minecan', 'constantin', '01-04-2008', 54943, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (19852, 329, 13, 'pinzaru', 'bianca', '16-08-2015', 70563, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (95188, 563, 70, 'brinzac', 'teodor', '17-10-2012', 62674, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (81003, 300, 12, 'stratu', 'bianca', '01-10-2014', 64258, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (97049, 207, 71, 'popescu', 'andrei', '07-09-2008', 72410, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (85575, 408, 70, 'cuzic', 'sorin', '06-11-2016', 65661, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (33279, 102, 12, 'cuzic', 'constantin', '27-11-2006', 44914, 1);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (44366, 105, 'maftei', 'valentin', '15-11-2005', 40223, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (65045, 568, 83, 'onciuleanu', 'stefana', '17-09-2011', 60210, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (79989, 903, 74, 'popovici', 'denis', '18-12-2009', 73612, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (81244, 568, 82, 'mindrescu', 'antonia', '11-10-2011', 24314, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (25275, 207, 81, 'jitareanu', 'alexandru', '21-08-2008', 96901, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (71224, 902, 80, 'budeanu', 'antonia', '09-11-2009', 5099, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (80663, 408, 12, 'stratu', 'isabela', '05-08-2016', 43942, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (32129, 330, 14, 'berbecariu', 'isabela', '01-07-2015', 60630, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (86601, 102, 82, 'brinzac', 'ioana', '24-01-2006', 38098, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (71886, 210, 14, 'boca', 'valentina', '26-12-2007', 25320, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (26599, 561, 74, 'cujba', 'eduard', '23-02-2012', 95155, 0);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (27827, 211, 'jitareanu', 'gabriela', '14-10-2007', 67348, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (76700, 469, 74, 'bistriceanu', 'mihai', '05-07-2013', 99580, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (37671, 209, 12, 'penescu', 'antonia', '12-05-2008', 26971, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (30736, 301, 57, 'berbecariu', 'adrian', '01-03-2014', 78015, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (23455, 580, 70, 'pinzaru', 'constantin', '14-04-2010', 66237, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (41915, 101, 73, 'cozorici', 'alexandru', '15-11-2006', 73037, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (32887, 212, 80, 'budeanu', 'valentina', '06-12-2007', 20950, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (74966, 561, 13, 'alexa', 'robert', '09-05-2012', 25328, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (79107, 104, 13, 'budeanu', 'daria', '21-10-2005', 86586, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (26503, 80, 82, 'birleanu', 'eduard', '16-08-2004', 95739, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (15687, 904, 74, 'amoraritei', 'matei', '06-10-2009', 66156, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (32131, 580, 56, 'basarab', 'alexandru', '09-03-2010', 51521, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (78084, 903, 13, 'boca', 'valentin', '10-04-2009', 2664, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (77632, 560, 10, 'ursaciuc', 'narcisa', '07-04-2012', 992, 1);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (66790, 580, 'mocanu', 'mihai', '15-03-2010', 78968, 0);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (17661, 101, 'boamba', 'teodor', '21-02-2006', 51354, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (41056, 467, 81, 'birleanu', 'narcisa', '24-09-2013', 78993, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (65478, 210, 10, 'munteanu', 'claudia', '03-05-2007', 7174, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (34763, 565, 72, 'cuzic', 'robert', '05-09-2011', 34044, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (18985, 211, 73, 'jitareanu', 'eduard', '22-04-2007', 14466, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (92504, 80, 11, 'onciuleanu', 'sorin', '01-01-2004', 97566, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (51056, 467, 57, 'jitareanu', 'petruta', '16-01-2013', 46483, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (97724, 303, 73, 'cojocaru', 'mihaela', '12-08-2014', 22239, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (76297, 901, 73, 'maftei', 'miruna', '18-07-2009', 46092, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (33799, 901, 10, 'radu', 'vasile', '14-09-2009', 40734, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (82246, 104, 12, 'radu', 'dan', '07-05-2005', 95674, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (35731, 105, 80, 'apetrei', 'cosmin', '21-08-2005', 93854, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (42853, 208, 72, 'apostol', 'stefana', '19-12-2008', 5136, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (59573, 582, 12, 'bistriceanu', 'andreea', '24-02-2010', 42411, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (49858, 408, 14, 'popescu', 'adrian', '21-04-2016', 38794, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (99911, 568, 72, 'penescu', 'dan', '01-07-2011', 66317, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (97706, 213, 72, 'pinzaru', 'roland', '13-09-2007', 53150, 0);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (93748, 902, 'amoraritei', 'narcisa', '13-04-2009', 68026, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (23630, 581, 14, 'basarab', 'valentin', '12-02-2010', 97288, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (13170, 408, 71, 'cuzic', 'ioana', '12-03-2016', 11253, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (10575, 209, 80, 'mocanu', 'isabela', '10-07-2008', 9768, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (69929, 81, 82, 'onciuleanu', 'vasile', '21-08-2004', 43538, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (11400, 408, 83, 'boamba', 'eduard', '01-10-2016', 18362, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (20134, 407, 57, 'meran', 'daria', '04-01-2016', 89649, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (41542, 212, 72, 'cojocaru', 'ioana', '24-06-2007', 8521, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (60725, 210, 83, 'budeanu', 'andreea', '06-02-2007', 60195, 1);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (91433, 563, 'ursaciuc', 'irina', '04-04-2012', 58611, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (46399, 580, 13, 'boca', 'ionela', '03-10-2010', 9728, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (84873, 407, 74, 'cojocaru', 'daria', '11-03-2016', 28157, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (56729, 101, 73, 'berbecariu', 'valentina', '02-08-2006', 4138, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (81354, 210, 56, 'maftei', 'teodor', '24-10-2007', 88245, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (41813, 107, 81, 'popescu', 'ioana', '11-11-2005', 77374, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (95857, 407, 10, 'popovici', 'sorin', '13-02-2016', 62921, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (11594, 469, 82, 'clem', 'antonia', '19-11-2013', 61801, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (18136, 468, 11, 'birleanu', 'sorin', '21-06-2013', 44893, 0);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (34285, 560, 'budeanu', 'roland', '28-02-2012', 50222, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (32651, 467, 82, 'amoraritei', 'sorin', '04-06-2013', 29970, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (84498, 903, 80, 'stefanoaia', 'vasile', '19-11-2009', 25097, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (86053, 902, 56, 'tibulca', 'mihai', '04-05-2009', 89617, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (35283, 580, 70, 'birleanu', 'irina', '12-10-2010', 8819, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (34961, 327, 73, 'popescu', 'roland', '29-09-2015', 34100, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (67084, 903, 10, 'boca', 'cosmin', '05-09-2009', 31970, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (53388, 468, 80, 'popovici', 'andreea', '07-11-2013', 67437, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (77928, 406, 80, 'bistriceanu', 'irina', '15-03-2016', 64415, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (96162, 582, 10, 'boca', 'isabela', '20-03-2010', 14752, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (59829, 303, 71, 'stratu', 'andreea', '03-11-2014', 81893, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (13931, 406, 82, 'boamba', 'vasile', '15-05-2016', 20978, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (96342, 580, 80, 'dima', 'eduard', '03-11-2010', 72092, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (59825, 105, 73, 'brinzac', 'valentina', '27-03-2005', 32709, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (79766, 467, 70, 'alexa', 'viviana', '01-08-2013', 36022, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (86557, 902, 12, 'munteanu', 'daria', '24-09-2009', 51051, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (84475, 565, 11, 'boca', 'teodor', '10-04-2011', 45862, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (79308, 568, 13, 'penescu', 'narcisa', '26-10-2011', 25372, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (49878, 407, 73, 'cuzic', 'eduard', '22-04-2016', 10862, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (95640, 207, 72, 'popescu', 'viviana', '24-02-2008', 23473, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (18177, 902, 81, 'apostol', 'isabela', '13-05-2009', 40503, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (20449, 902, 14, 'onciuleanu', 'matei', '09-12-2009', 84818, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (95309, 407, 73, 'cujba', 'petruta', '01-12-2016', 70735, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (59054, 330, 56, 'cuzic', 'antonia', '06-08-2015', 61926, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (49349, 468, 10, 'amoraritei', 'stefana', '10-08-2013', 35414, 0);
insert into ELEV(nr_matricol, id_clasa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (14991, 582, 'budeanu', 'adrian', '12-05-2010', 5399, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (48303, 104, 12, 'maftei', 'cosmin', '15-03-2005', 23823, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (60798, 468, 13, 'ursaciuc', 'roland', '02-08-2013', 86470, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (59985, 582, 14, 'popovici', 'antonia', '26-04-2010', 26620, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (37250, 580, 13, 'basarab', 'ionela', '04-10-2010', 78941, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (51581, 581, 10, 'cujba', 'stefana', '17-04-2010', 86884, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (30730, 104, 10, 'alexa', 'isabela', '16-02-2005', 51256, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (27911, 582, 80, 'pinzaru', 'sorin', '28-05-2010', 9994, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (37880, 105, 10, 'dima', 'sorin', '29-04-2005', 32985, 0);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (47168, 301, 70, 'stefanoaia', 'constantin', '03-10-2014', 90462, 1);
insert into ELEV(nr_matricol, id_clasa, id_bursa, nume, prenume, data_nasterii, venit_parinti, conditie_medicala)
values (12276, 101, 81, 'cozorici', 'claudia', '22-01-2006', 89614, 1);


create table CONT (
cont_bancar varchar2(24) not null primary key, 
nr_matricol number(5, 0) not null,
id_banca varchar2(20) not null,
foreign key(nr_matricol) references ELEV(nr_matricol),
foreign key(id_banca) references BANCA(id_banca)
);

insert into CONT values ('RO7881132643572434374061', 39499, 'BNR');
insert into CONT values ('RO8746072461655937447059', 46399, 'BNR');
insert into CONT values ('RO6100946526770386863817', 92504, 'CEC');
insert into CONT values ('RO9466029430642663213300', 11400, 'BRD');
insert into CONT values ('RO1855925345377935923693', 84475, 'BRD');
insert into CONT values ('RO4341414411281404311402', 50210, 'BCR');
insert into CONT values ('RO6101144061965768034605', 74966, 'BNR');
insert into CONT values ('RO1784108701832315569535', 58035, 'BRD');
insert into CONT values ('RO1321602910232438721460', 39639, 'OTP');
insert into CONT values ('RO5016761659842296956364', 74966, 'BT');
insert into CONT values ('RO7688439158812764627799', 19274, 'Raiffeisen');
insert into CONT values ('RO8228060977325004763065', 15269, 'Raiffeisen');
insert into CONT values ('RO7256199405500099041990', 73805, 'BT');
insert into CONT values ('RO2501635753300101790484', 10575, 'ING');
insert into CONT values ('RO7877548367964646720729', 23630, 'BRD');
insert into CONT values ('RO6690899228972056223690', 48418, 'CEC');
insert into CONT values ('RO2836066494405616711439', 63531, 'CEC');
insert into CONT values ('RO3528427358364702316798', 93748, 'CEC');
insert into CONT values ('RO9493576624684624332727', 76297, 'BNR');
insert into CONT values ('RO5008643483781189575761', 35731, 'BCR');
insert into CONT values ('RO6922097781186627471833', 78878, 'UniCredit');
insert into CONT values ('RO3873424585322688800036', 79989, 'CEC');
insert into CONT values ('RO9188500631660801796081', 18177, 'ING');
insert into CONT values ('RO2759395838009425324022', 60725, 'OTP');
insert into CONT values ('RO2670976450722135103210', 41542, 'CEC');
insert into CONT values ('RO6790960001262305103335', 32887, 'CEC');
insert into CONT values ('RO3553762674193901831193', 35731, 'BCR');
insert into CONT values ('RO5115856151554889626955', 60725, 'BNR');
insert into CONT values ('RO7605380512816444307940', 91433, 'BNR');
insert into CONT values ('RO4913314476988050882097', 18177, 'BNR');
insert into CONT values ('RO5869305665133972282762', 84475, 'UniCredit');
insert into CONT values ('RO9292819366358888334930', 96342, 'UniCredit');
insert into CONT values ('RO4552432724046488329394', 71886, 'BCR');
insert into CONT values ('RO3361529554166576633378', 12019, 'CEC');
insert into CONT values ('RO4053220633203134824789', 42980, 'CEC');
insert into CONT values ('RO4057237213044285332953', 14991, 'BRD');
insert into CONT values ('RO7844051726257014656095', 20134, 'CEC');
insert into CONT values ('RO2422895154794680544184', 74535, 'OTP');
insert into CONT values ('RO8061624426252572618275', 18136, 'Raiffeisen');
insert into CONT values ('RO3695143515044593761668', 85447, 'BRD');
insert into CONT values ('RO5549300083113774770864', 41050, 'BNR');
insert into CONT values ('RO1831955996142298661066', 20449, 'BT');
insert into CONT values ('RO2610375641907743631644', 65045, 'BNR');
insert into CONT values ('RO9376376561067447868122', 77632, 'UniCredit');
insert into CONT values ('RO9500864086691344707074', 67084, 'ING');
insert into CONT values ('RO9084763538862317411921', 86053, 'BCR');
insert into CONT values ('RO5672383996851525568989', 26503, 'ING');
insert into CONT values ('RO1536471138498193179396', 18580, 'ING');
insert into CONT values ('RO7864705342888477489796', 41056, 'BRD');
insert into CONT values ('RO8814157494568666826391', 11400, 'CEC');
insert into CONT values ('RO9465334607648157161537', 17661, 'BCR');
insert into CONT values ('RO4652045972797192633327', 81354, 'ING');
insert into CONT values ('RO5241182474948886963539', 13931, 'OTP');
insert into CONT values ('RO1809492716558314981627', 68054, 'ING');
insert into CONT values ('RO4039455066167553861073', 93748, 'Raiffeisen');
insert into CONT values ('RO6987477364905142746968', 53388, 'BRD');
insert into CONT values ('RO8372642502188741330360', 27827, 'ING');
insert into CONT values ('RO2528121354235553536079', 25275, 'Raiffeisen');
insert into CONT values ('RO3632680282220566771644', 87892, 'BNR');
insert into CONT values ('RO8328968267065325027238', 39639, 'BT');
insert into CONT values ('RO1116048096663900769238', 18177, 'UniCredit');
insert into CONT values ('RO8456633770297899643375', 60798, 'ING');
insert into CONT values ('RO6819158814113006072196', 34961, 'OTP');
insert into CONT values ('RO7057792804293112497443', 18177, 'BT');
insert into CONT values ('RO8605756511129573608922', 68054, 'BT');
insert into CONT values ('RO2598121522239127264887', 11594, 'Raiffeisen');
insert into CONT values ('RO7591172648478318727354', 11400, 'UniCredit');
insert into CONT values ('RO6951643749523307526797', 99911, 'CEC');
insert into CONT values ('RO3109452535104317677929', 46399, 'ING');
insert into CONT values ('RO9905302952305633590960', 34008, 'BNR');
insert into CONT values ('RO2316083481262170490108', 78084, 'BNR');
insert into CONT values ('RO1694255498192127426059', 20449, 'ING');
insert into CONT values ('RO7807921383758921778599', 34285, 'CEC');
insert into CONT values ('RO8642776366502797297265', 79308, 'UniCredit');
insert into CONT values ('RO3534983515086108018584', 26503, 'BT');
insert into CONT values ('RO6317250282696087489530', 52700, 'BCR');
insert into CONT values ('RO4811675331184962714142', 37725, 'CEC');
insert into CONT values ('RO5776521374064417432118', 59321, 'ING');
insert into CONT values ('RO6816042856228905531763', 71447, 'BT');
insert into CONT values ('RO2516720050821284439953', 76959, 'BCR');
insert into CONT values ('RO5001637440314826037328', 89489, 'UniCredit');
insert into CONT values ('RO9671390707154029514498', 91433, 'BRD');
insert into CONT values ('RO9687324111144495146675', 78878, 'OTP');
insert into CONT values ('RO5050834838789583885497', 41813, 'UniCredit');
insert into CONT values ('RO7676957601288701311137', 69929, 'BRD');
insert into CONT values ('RO5770521666486907957852', 13170, 'BT');
insert into CONT values ('RO3675807675474628871727', 12019, 'ING');
insert into CONT values ('RO1608507184351914550303', 47168, 'BNR');
insert into CONT values ('RO5568776473792277096603', 70839, 'BNR');
insert into CONT values ('RO5681334277659363353955', 79308, 'Raiffeisen');
insert into CONT values ('RO2338668776921084703103', 71886, 'CEC');
insert into CONT values ('RO6426635570409032542562', 11702, 'ING');
insert into CONT values ('RO6936603058018210286647', 86053, 'UniCredit');
insert into CONT values ('RO5370860540793210952658', 37671, 'ING');
insert into CONT values ('RO6613252767731840290673', 37156, 'ING');
insert into CONT values ('RO7138766139917008625940', 85447, 'BCR');
insert into CONT values ('RO2912362419089360198855', 32129, 'BRD');
insert into CONT values ('RO5482330135574415259445', 41813, 'Raiffeisen');
insert into CONT values ('RO3285865826336435593298', 46821, 'ING');
insert into CONT values ('RO8838186821145347861645', 71886, 'BRD');
insert into CONT values ('RO8800281423642939161963', 41915, 'BT');
insert into CONT values ('RO6524673419461936315139', 41915, 'Raiffeisen');

create table BANCA (
id_banca varchar2(20) not null primary key,
nume varchar2(35) not null,
adresa varchar2(40) 
);

insert into BANCA values ('BT', 'Banca Transilvania', 'Calea unirii');
insert into BANCA values ('BCR', 'Banca Comerciala Romana', 'Splaiul Independentei');
insert into BANCA values ('Raiffeisen', 'Raiffeisen Bank', 'Mihai Eminescu');
insert into BANCA values ('BNR', 'Banca Nationala Romana', '9 mai');
insert into BANCA values ('ING', 'ING Groep','Republicii');
insert into BANCA values ('CEC', 'Casa de Economii ?i Consemna?iuni', 'Calea nationala');
insert into BANCA values ('BRD', 'BRD-SocGen', 'Iasilor');
insert into BANCA values ('UniCredit', 'UniCredit Bank', 'Bulevardul unirii');
insert into BANCA values ('OTP', 'OTP Bank', 'Bulevardul Nicolae');

create sequence generare_cod_olimpiada
Start with 10000
Increment by 1;

create table OLIMPIADA (
cod_olimpiada number(5, 0) not null primary key,
disciplina varchar2(30) not null
);

insert into OLIMPIADA values (generare_cod_olimpiada.nextval, 'matematica');
insert into OLIMPIADA values (generare_cod_olimpiada.nextval, 'fizica');
insert into OLIMPIADA values (generare_cod_olimpiada.nextval, 'chimie');
insert into OLIMPIADA values (generare_cod_olimpiada.nextval, 'limba engleza');
insert into OLIMPIADA values (generare_cod_olimpiada.nextval, 'limba si literatura romana');
insert into OLIMPIADA values (generare_cod_olimpiada.nextval, 'biologie');
insert into OLIMPIADA values (generare_cod_olimpiada.nextval, 'limba franceza');
insert into OLIMPIADA values (generare_cod_olimpiada.nextval, 'astronomie');
insert into OLIMPIADA values (generare_cod_olimpiada.nextval, 'informatica');

create table PROIECT (
id_proiect number(4, 0) not null primary key,
nume varchar2(25) not null, 
nr_punctaj number(3, 1) not null
);

insert into PROIECT values (0, 'entropia limbii romane', 80);
insert into PROIECT values (1, 'criptare mesaj', 70);
insert into PROIECT values (2, 'istoria religiilor', 50);
insert into PROIECT values (3, 'reactii chimice', 60);
insert into PROIECT values (4, 'fenomene extreme', 20);
insert into PROIECT values (5, 'matematica in medicina', 90);
insert into PROIECT values (6, 'arhitectura bizantina', 35);

create table BURSA (
id_bursa number(2, 0) not null primary key, 
suma number(3, 0) not  null
);

insert into BURSA values (80, 705);
insert into BURSA values (81, 700);
insert into BURSA values (82, 710);
insert into BURSA values (83, 700);
insert into BURSA values (57, 980);
insert into BURSA values (70, 250);
insert into BURSA values (71, 260);
insert into BURSA values (72, 270);
insert into BURSA values (73, 280);
insert into BURSA values (74, 290);
insert into BURSA values (56, 990);
insert into BURSA values (10, 150);
insert into BURSA values (11, 160);
insert into BURSA values (12, 170);
insert into BURSA values (13, 880);
insert into BURSA values (14, 190);

create table BURSA_SOCIALA (
id_social number(2, 0) not null primary key,
categorie varchar2(10) not null, 
foreign key(id_social) references BURSA(id_bursa)
);

insert into BURSA_SOCIALA values (80, 'venit');
insert into BURSA_SOCIALA values (81, 'venit');
insert into BURSA_SOCIALA values (82, 'venit');
insert into BURSA_SOCIALA values (56, 'medical');
insert into BURSA_SOCIALA values (57, 'medical');

create table BURSA_MERIT (
id_merit number(2, 0) not null primary key,
medie_minima number(2, 1) not null,
punctaj_minim number(2, 0) not null,
foreign key(id_merit) references BURSA(id_bursa)
);

insert into BURSA_MERIT values (10, 7.5, 50);
insert into BURSA_MERIT values (14, 6.5, 70);
insert into BURSA_MERIT values (11, 5.5, 90);
insert into BURSA_MERIT values (12, 8, 20);
insert into BURSA_MERIT values (13, 9, 10);

create table BURSA_PERFORMANTA (
id_performanta number(2, 0) not null primary key,
loc_minim number(1, 0) not null,
foreign key(id_performanta) references BURSA(id_bursa)
);

insert into BURSA_PERFORMANTA values (70, 2);
insert into BURSA_PERFORMANTA values (71, 3);
insert into BURSA_PERFORMANTA values (72, 2);
insert into BURSA_PERFORMANTA values (73, 1);
insert into BURSA_PERFORMANTA values (74, 6);

create table PREDA (
cod_profesor number(4, 0) not null,
id_clasa number(3, 0) not null, 
id_materie number(2, 0) not null,
zi_lectie number(1, 0) not null, 
ora number(2, 0) not null,

constraint pk_preda primary key(cod_profesor, id_clasa, id_materie)
);

alter table PREDA add foreign key(cod_profesor) references PROFESOR(cod_profesor);
alter table PREDA add foreign key(id_clasa) references CLASA(id_clasa);
alter table PREDA add foreign key(id_materie) references MATERIE(id_materie);

insert into PREDA values (213, 470, 1, 1, 15);
insert into PREDA values (152, 470, 11, 1, 15);
insert into PREDA values (90, 904, 1, 1, 15);
insert into PREDA values (118, 208, 20, 1, 12);
insert into PREDA values (194, 302, 9, 1, 11);
insert into PREDA values (90, 407, 13, 5, 14);
insert into PREDA values (22, 468, 2, 2, 19);
insert into PREDA values (194, 206, 13, 3, 15);
insert into PREDA values (27, 407, 7, 1, 17);
insert into PREDA values (128, 212, 16, 3, 8);
insert into PREDA values (161, 106, 3, 2, 16);
insert into PREDA values (136, 581, 10, 2, 15);
insert into PREDA values (152, 408, 1, 3, 9);
insert into PREDA values (48, 467, 12, 1, 16);
insert into PREDA values (164, 582, 17, 3, 10);
insert into PREDA values (191, 901, 5, 3, 12);
insert into PREDA values (200, 213, 19, 5, 9);
insert into PREDA values (138, 468, 13, 3, 10);
insert into PREDA values (48, 81, 8, 3, 15);
insert into PREDA values (200, 330, 7, 4, 17);
insert into PREDA values (128, 405, 15, 4, 11);
insert into PREDA values (136, 208, 7, 4, 8);
insert into PREDA values (199, 582, 13, 2, 8);
insert into PREDA values (117, 469, 10, 5, 19);
insert into PREDA values (138, 583, 15, 4, 8);
insert into PREDA values (27, 100, 12, 3, 8);
insert into PREDA values (161, 406, 9, 2, 17);
insert into PREDA values (136, 583, 12, 4, 12);
insert into PREDA values (200, 566, 6, 3, 11);
insert into PREDA values (118, 207, 12, 3, 12);
insert into PREDA values (191, 560, 15, 4, 12);
insert into PREDA values (138, 206, 13, 5, 13);
insert into PREDA values (129, 583, 16, 2, 16);
insert into PREDA values (22, 206, 13, 3, 14);
insert into PREDA values (194, 468, 9, 5, 15);
insert into PREDA values (173, 208, 18, 4, 9);
insert into PREDA values (5, 902, 2, 5, 15);
insert into PREDA values (27, 327, 12, 2, 12);
insert into PREDA values (118, 468, 1, 1, 9);
insert into PREDA values (173, 562, 14, 2, 18);
insert into PREDA values (124, 302, 7, 5, 11);
insert into PREDA values (199, 81, 1, 2, 9);
insert into PREDA values (138, 106, 8, 1, 15);
insert into PREDA values (129, 408, 4, 1, 10);
insert into PREDA values (27, 469, 11, 4, 10);
insert into PREDA values (199, 567, 9, 2, 18);
insert into PREDA values (194, 82, 1, 3, 9);
insert into PREDA values (152, 467, 11, 1, 13);
insert into PREDA values (200, 327, 15, 2, 9);
insert into PREDA values (129, 581, 7, 3, 15);
insert into PREDA values (128, 302, 19, 1, 10);
insert into PREDA values (22, 81, 19, 3, 13);
insert into PREDA values (194, 563, 1, 2, 14);
insert into PREDA values (23, 329, 13, 1, 11);
insert into PREDA values (200, 100, 4, 1, 14);
insert into PREDA values (124, 211, 3, 1, 8);
insert into PREDA values (128, 901, 18, 5, 18);
insert into PREDA values (138, 107, 7, 5, 9);
insert into PREDA values (194, 902, 9, 3, 11);
insert into PREDA values (23, 104, 17, 2, 17);
insert into PREDA values (124, 100, 19, 2, 19);
insert into PREDA values (138, 408, 19, 3, 13);
insert into PREDA values (161, 562, 6, 4, 16);
insert into PREDA values (161, 467, 10, 4, 12);
insert into PREDA values (27, 213, 10, 1, 11);
insert into PREDA values (136, 904, 1, 1, 11);
insert into PREDA values (22, 209, 9, 1, 15);
insert into PREDA values (199, 210, 6, 3, 17);
insert into PREDA values (173, 103, 20, 3, 12);
insert into PREDA values (48, 581, 11, 1, 10);
insert into PREDA values (117, 106, 17, 5, 11);
insert into PREDA values (117, 562, 18, 1, 10);
insert into PREDA values (164, 406, 4, 4, 16);
insert into PREDA values (23, 211, 5, 2, 19);
insert into PREDA values (61, 467, 19, 3, 18);
insert into PREDA values (152, 209, 2, 2, 9);
insert into PREDA values (118, 902, 1, 2, 9);
insert into PREDA values (48, 567, 17, 3, 13);
insert into PREDA values (199, 104, 17, 2, 11);
insert into PREDA values (199, 467, 19, 1, 11);
insert into PREDA values (136, 561, 20, 5, 14);
insert into PREDA values (27, 105, 19, 1, 14);
insert into PREDA values (191, 213, 13, 5, 15);
insert into PREDA values (136, 468, 3, 5, 10);
insert into PREDA values (90, 561, 9, 1, 9);
insert into PREDA values (173, 405, 5, 1, 19);
insert into PREDA values (90, 563, 14, 4, 17);
insert into PREDA values (124, 212, 15, 5, 10);
insert into PREDA values (5, 567, 13, 3, 16);
insert into PREDA values (5, 107, 1, 2, 18);
insert into PREDA values (118, 303, 16, 2, 19);
insert into PREDA values (128, 208, 19, 3, 15);
insert into PREDA values (138, 901, 1, 1, 8);
insert into PREDA values (23, 563, 16, 1, 14);
insert into PREDA values (90, 300, 8, 3, 11);
insert into PREDA values (128, 405, 2, 3, 9);
insert into PREDA values (118, 103, 4, 5, 10);
insert into PREDA values (48, 301, 2, 3, 18);
insert into PREDA values (199, 580, 13, 1, 15);
insert into PREDA values (173, 561, 13, 2, 10);
insert into PREDA values (118, 81, 1, 3, 19);
insert into PREDA values (199, 207, 5, 3, 16);
insert into PREDA values (61, 103, 2, 1, 15);
insert into PREDA values (124, 303, 11, 1, 8);
insert into PREDA values (164, 902, 7, 5, 17);
insert into PREDA values (161, 568, 6, 4, 10);
insert into PREDA values (137, 566, 17, 4, 11);
insert into PREDA values (5, 210, 8, 4, 9);
insert into PREDA values (194, 103, 15, 5, 10);
insert into PREDA values (194, 81, 10, 1, 13);
insert into PREDA values (118, 327, 15, 4, 17);
insert into PREDA values (90, 469, 2, 5, 15);
insert into PREDA values (200, 330, 6, 4, 17);
insert into PREDA values (61, 566, 12, 4, 8);
insert into PREDA values (124, 567, 16, 5, 17);
insert into PREDA values (124, 903, 11, 2, 18);
insert into PREDA values (128, 327, 3, 1, 18);
insert into PREDA values (124, 107, 8, 4, 8);
insert into PREDA values (90, 469, 11, 5, 15);
insert into PREDA values (136, 568, 10, 4, 16);
insert into PREDA values (90, 206, 8, 5, 17);
insert into PREDA values (161, 105, 16, 1, 15);
insert into PREDA values (124, 100, 10, 5, 13);
insert into PREDA values (191, 470, 1, 3, 12);
insert into PREDA values (173, 210, 11, 5, 15);
insert into PREDA values (5, 83, 8, 4, 14);
insert into PREDA values (90, 583, 18, 4, 12);
insert into PREDA values (61, 106, 18, 3, 9);
insert into PREDA values (199, 904, 2, 5, 11);
insert into PREDA values (191, 902, 3, 2, 19);
insert into PREDA values (124, 213, 9, 2, 8);
insert into PREDA values (23, 82, 1, 4, 12);
insert into PREDA values (173, 209, 11, 5, 10);
insert into PREDA values (90, 211, 15, 4, 14);
insert into PREDA values (61, 562, 13, 3, 10);
insert into PREDA values (136, 101, 1, 3, 15);
insert into PREDA values (199, 206, 2, 3, 12);
insert into PREDA values (124, 213, 8, 5, 10);
insert into PREDA values (23, 901, 14, 1, 10);
insert into PREDA values (138, 103, 13, 1, 11);
insert into PREDA values (199, 560, 19, 5, 16);
insert into PREDA values (129, 106, 8, 3, 10);
insert into PREDA values (164, 470, 6, 1, 18);
insert into PREDA values (191, 901, 19, 3, 11);
insert into PREDA values (27, 303, 10, 1, 8);
insert into PREDA values (48, 568, 11, 2, 8);
insert into PREDA values (124, 327, 16, 5, 14);
insert into PREDA values (118, 469, 19, 1, 14);
insert into PREDA values (173, 405, 4, 3, 11);
insert into PREDA values (124, 300, 16, 3, 9);
insert into PREDA values (200, 408, 5, 5, 15);
insert into PREDA values (161, 301, 17, 1, 17);
insert into PREDA values (129, 566, 10, 5, 14);
insert into PREDA values (164, 407, 19, 2, 12);
insert into PREDA values (27, 903, 10, 1, 13);
insert into PREDA values (191, 560, 7, 5, 14);
insert into PREDA values (22, 581, 17, 4, 18);
insert into PREDA values (152, 567, 15, 5, 17);
insert into PREDA values (124, 303, 13, 5, 8);
insert into PREDA values (164, 208, 6, 3, 12);
insert into PREDA values (129, 405, 11, 5, 15);
insert into PREDA values (152, 408, 9, 2, 15);
insert into PREDA values (27, 468, 4, 5, 15);
insert into PREDA values (199, 470, 18, 5, 12);
insert into PREDA values (152, 81, 16, 2, 15);
insert into PREDA values (27, 80, 19, 1, 14);
insert into PREDA values (124, 581, 12, 3, 8);
insert into PREDA values (23, 102, 18, 4, 8);
insert into PREDA values (173, 213, 18, 3, 9);
insert into PREDA values (199, 901, 17, 5, 13);
insert into PREDA values (27, 583, 5, 5, 11);
insert into PREDA values (138, 102, 10, 1, 19);
insert into PREDA values (23, 209, 13, 4, 13);
insert into PREDA values (128, 580, 18, 3, 13);
insert into PREDA values (128, 102, 13, 2, 11);
insert into PREDA values (129, 207, 4, 5, 15);
insert into PREDA values (161, 209, 4, 3, 10);
insert into PREDA values (164, 100, 5, 1, 10);
insert into PREDA values (199, 566, 10, 2, 10);
insert into PREDA values (164, 104, 7, 5, 12);
insert into PREDA values (128, 328, 16, 1, 9);
insert into PREDA values (137, 566, 7, 1, 9);
insert into PREDA values (161, 470, 14, 4, 16);
insert into PREDA values (129, 206, 12, 4, 13);
insert into PREDA values (200, 562, 12, 2, 8);
insert into PREDA values (199, 211, 7, 5, 16);
insert into PREDA values (191, 582, 2, 2, 17);
insert into PREDA values (124, 103, 12, 1, 15);
insert into PREDA values (136, 209, 7, 2, 9);
insert into PREDA values (61, 327, 10, 5, 14);
insert into PREDA values (136, 565, 7, 1, 16);
insert into PREDA values (117, 566, 3, 2, 16);
insert into PREDA values (90, 469, 7, 3, 8);
insert into PREDA values (194, 206, 3, 4, 12);
insert into PREDA values (27, 211, 13, 2, 11);
insert into PREDA values (61, 568, 3, 4, 19);
insert into PREDA values (61, 904, 14, 1, 15);
insert into PREDA values (23, 209, 14, 2, 16);
insert into PREDA values (48, 330, 9, 1, 19);
insert into PREDA values (129, 467, 1, 3, 14);
insert into PREDA values (173, 468, 9, 1, 9);
insert into PREDA values (137, 405, 6, 2, 15);
insert into PREDA values (48, 327, 17, 2, 16);
insert into PREDA values (164, 581, 20, 4, 15);
insert into PREDA values (137, 107, 1, 1, 19);
insert into PREDA values (117, 405, 3, 2, 14);
insert into PREDA values (173, 562, 6, 4, 17);
insert into PREDA values (152, 568, 9, 2, 16);
insert into PREDA values (124, 568, 14, 1, 16);
insert into PREDA values (137, 902, 9, 1, 19);
insert into PREDA values (152, 903, 16, 2, 15);
insert into PREDA values (173, 104, 10, 3, 19);
insert into PREDA values (124, 106, 18, 2, 14);
insert into PREDA values (152, 107, 19, 5, 11);
insert into PREDA values (124, 330, 11, 3, 18);
insert into PREDA values (23, 581, 20, 1, 18);
insert into PREDA values (61, 301, 14, 3, 19);
insert into PREDA values (152, 903, 2, 5, 13);
insert into PREDA values (48, 568, 6, 1, 19);
insert into PREDA values (200, 101, 3, 4, 12);
insert into PREDA values (138, 902, 13, 3, 10);
insert into PREDA values (199, 901, 7, 4, 14);
insert into PREDA values (124, 565, 9, 1, 19);
insert into PREDA values (191, 102, 14, 3, 14);
insert into PREDA values (118, 904, 6, 1, 18);
insert into PREDA values (27, 565, 14, 3, 10);
insert into PREDA values (5, 406, 4, 2, 17);
insert into PREDA values (191, 212, 2, 4, 19);
insert into PREDA values (23, 329, 1, 3, 14);
insert into PREDA values (136, 105, 15, 3, 14);
insert into PREDA values (90, 107, 14, 1, 13);
insert into PREDA values (117, 103, 8, 5, 9);
insert into PREDA values (61, 408, 14, 2, 12);
insert into PREDA values (164, 327, 17, 2, 13);
insert into PREDA values (90, 303, 11, 3, 15);
insert into PREDA values (23, 105, 5, 3, 12);
insert into PREDA values (199, 107, 15, 3, 9);
insert into PREDA values (23, 468, 5, 2, 15);
insert into PREDA values (90, 100, 20, 1, 15);
insert into PREDA values (191, 105, 2, 2, 9);
insert into PREDA values (27, 301, 15, 1, 17);
insert into PREDA values (117, 211, 14, 5, 9);
insert into PREDA values (90, 207, 14, 5, 10);
insert into PREDA values (200, 303, 8, 2, 10);
insert into PREDA values (90, 101, 8, 1, 10);
insert into PREDA values (137, 469, 7, 1, 10);
insert into PREDA values (48, 560, 16, 3, 13);
insert into PREDA values (124, 467, 3, 3, 13);
insert into PREDA values (194, 106, 8, 4, 8);
insert into PREDA values (128, 303, 13, 4, 11);
insert into PREDA values (200, 562, 18, 5, 16);
insert into PREDA values (27, 470, 3, 3, 9);
insert into PREDA values (90, 405, 8, 2, 9);
insert into PREDA values (199, 405, 20, 2, 18);
insert into PREDA values (5, 212, 15, 5, 19);
insert into PREDA values (22, 303, 1, 5, 13);
insert into PREDA values (5, 568, 13, 3, 17);
insert into PREDA values (200, 104, 15, 4, 12);
insert into PREDA values (191, 301, 17, 1, 16);
insert into PREDA values (200, 104, 16, 5, 9);
insert into PREDA values (161, 100, 14, 5, 10);
insert into PREDA values (194, 408, 16, 4, 13);
insert into PREDA values (191, 329, 13, 5, 14);
insert into PREDA values (173, 902, 3, 5, 10);
insert into PREDA values (137, 563, 20, 5, 15);
insert into PREDA values (22, 303, 20, 5, 8);
insert into PREDA values (128, 561, 18, 2, 17);
insert into PREDA values (161, 101, 15, 4, 18);
insert into PREDA values (173, 106, 16, 5, 9);
insert into PREDA values (23, 469, 10, 2, 10);
insert into PREDA values (200, 468, 5, 3, 17);
insert into PREDA values (199, 468, 4, 1, 9);
insert into PREDA values (124, 470, 5, 1, 14);
insert into PREDA values (22, 303, 10, 3, 19);
insert into PREDA values (136, 211, 13, 5, 8);
insert into PREDA values (191, 902, 14, 3, 9);
insert into PREDA values (61, 566, 1, 5, 9);
insert into PREDA values (117, 105, 12, 3, 18);
insert into PREDA values (129, 563, 17, 1, 14);
insert into PREDA values (48, 102, 5, 2, 8);
insert into PREDA values (136, 327, 12, 1, 18);
insert into PREDA values (118, 329, 14, 4, 9);
insert into PREDA values (199, 328, 14, 5, 13);
insert into PREDA values (27, 468, 2, 3, 11);
insert into PREDA values (22, 210, 17, 2, 12);
insert into PREDA values (164, 81, 7, 5, 18);
insert into PREDA values (199, 83, 20, 2, 9);
insert into PREDA values (117, 100, 14, 1, 13);
insert into PREDA values (191, 328, 3, 1, 12);
insert into PREDA values (117, 904, 10, 4, 16);
insert into PREDA values (128, 303, 10, 1, 18);
insert into PREDA values (164, 105, 13, 1, 19);
insert into PREDA values (118, 408, 19, 3, 9);
insert into PREDA values (118, 101, 5, 1, 9);
insert into PREDA values (48, 566, 1, 1, 9);
insert into PREDA values (61, 903, 20, 3, 17);
insert into PREDA values (90, 328, 10, 4, 9);
insert into PREDA values (90, 104, 19, 1, 12);
insert into PREDA values (152, 302, 14, 1, 18);
insert into PREDA values (200, 580, 4, 5, 8);
insert into PREDA values (48, 208, 10, 5, 18);
insert into PREDA values (136, 83, 19, 1, 12);
insert into PREDA values (128, 327, 19, 3, 15);
insert into PREDA values (48, 103, 11, 4, 11);
insert into PREDA values (117, 210, 9, 1, 9);
insert into PREDA values (5, 469, 10, 4, 13);
insert into PREDA values (124, 405, 2, 4, 11);
insert into PREDA values (90, 107, 8, 5, 19);
insert into PREDA values (117, 82, 5, 5, 9);
insert into PREDA values (128, 405, 18, 1, 15);
insert into PREDA values (199, 102, 8, 5, 13);
insert into PREDA values (136, 330, 17, 5, 13);
insert into PREDA values (27, 80, 2, 5, 11);
insert into PREDA values (152, 330, 5, 2, 8);
insert into PREDA values (118, 210, 14, 2, 15);
insert into PREDA values (90, 903, 17, 1, 12);
insert into PREDA values (191, 567, 16, 4, 16);
insert into PREDA values (138, 82, 18, 4, 12);
insert into PREDA values (124, 82, 16, 3, 14);
insert into PREDA values (136, 328, 12, 3, 18);
insert into PREDA values (23, 106, 11, 2, 15);
insert into PREDA values (136, 82, 14, 4, 18);
insert into PREDA values (164, 580, 18, 4, 18);
insert into PREDA values (118, 565, 16, 5, 19);
insert into PREDA values (90, 903, 4, 4, 9);
insert into PREDA values (129, 103, 7, 5, 18);
insert into PREDA values (137, 902, 10, 2, 16);
insert into PREDA values (194, 467, 12, 1, 14);
insert into PREDA values (129, 902, 11, 3, 19);
insert into PREDA values (5, 105, 9, 5, 12);
insert into PREDA values (191, 327, 19, 5, 18);
insert into PREDA values (199, 303, 13, 1, 16);
insert into PREDA values (199, 560, 13, 2, 19);
insert into PREDA values (90, 83, 13, 5, 18);
insert into PREDA values (90, 106, 7, 3, 15);
insert into PREDA values (164, 210, 11, 4, 15);
insert into PREDA values (136, 107, 17, 5, 11);
insert into PREDA values (199, 106, 2, 2, 13);
insert into PREDA values (124, 82, 8, 3, 9);
insert into PREDA values (22, 560, 7, 2, 9);
insert into PREDA values (5, 566, 11, 2, 8);
insert into PREDA values (48, 902, 7, 4, 10);
insert into PREDA values (27, 329, 6, 2, 8);
insert into PREDA values (90, 327, 13, 1, 15);
insert into PREDA values (164, 580, 19, 2, 16);
insert into PREDA values (152, 407, 6, 4, 13);
insert into PREDA values (124, 561, 10, 4, 9);
insert into PREDA values (117, 327, 13, 2, 14);
insert into PREDA values (90, 213, 2, 3, 18);
insert into PREDA values (90, 303, 1, 3, 18);
insert into PREDA values (138, 212, 20, 2, 14);
insert into PREDA values (152, 209, 9, 1, 19);
insert into PREDA values (200, 565, 8, 4, 16);
insert into PREDA values (138, 302, 12, 2, 15);
insert into PREDA values (164, 406, 1, 1, 8);
insert into PREDA values (129, 329, 18, 2, 17);
insert into PREDA values (136, 330, 11, 2, 12);
insert into PREDA values (194, 300, 12, 3, 17);
insert into PREDA values (61, 560, 14, 4, 10);
insert into PREDA values (161, 902, 4, 3, 14);
insert into PREDA values (118, 327, 4, 4, 9);
insert into PREDA values (23, 582, 8, 5, 19);
insert into PREDA values (137, 303, 1, 2, 13);
insert into PREDA values (200, 467, 15, 1, 13);
insert into PREDA values (173, 104, 18, 5, 14);
insert into PREDA values (152, 561, 16, 2, 13);
insert into PREDA values (199, 209, 1, 4, 14);
insert into PREDA values (128, 104, 5, 1, 13);
insert into PREDA values (138, 468, 6, 5, 8);
insert into PREDA values (124, 80, 13, 4, 14);
insert into PREDA values (128, 581, 2, 1, 19);
insert into PREDA values (152, 566, 11, 1, 18);
insert into PREDA values (164, 83, 15, 3, 16);
insert into PREDA values (136, 566, 3, 4, 19);
insert into PREDA values (152, 901, 4, 3, 19);
insert into PREDA values (137, 107, 17, 2, 9);
insert into PREDA values (61, 468, 1, 5, 10);
insert into PREDA values (48, 330, 10, 2, 19);
insert into PREDA values (161, 904, 7, 1, 16);
insert into PREDA values (194, 103, 8, 5, 19);
insert into PREDA values (128, 568, 20, 5, 14);
insert into PREDA values (199, 207, 1, 5, 14);
insert into PREDA values (199, 105, 10, 5, 15);
insert into PREDA values (194, 301, 7, 1, 18);
insert into PREDA values (22, 328, 2, 1, 14);
insert into PREDA values (128, 407, 5, 1, 19);
insert into PREDA values (61, 209, 13, 1, 10);
insert into PREDA values (200, 560, 17, 3, 8);
insert into PREDA values (152, 903, 7, 3, 14);
insert into PREDA values (124, 101, 18, 3, 14);
insert into PREDA values (161, 582, 2, 3, 15);
insert into PREDA values (27, 300, 15, 4, 19);
insert into PREDA values (200, 302, 19, 5, 15);
insert into PREDA values (118, 567, 7, 5, 9);
insert into PREDA values (194, 212, 4, 1, 13);
insert into PREDA values (194, 100, 11, 5, 14);
insert into PREDA values (138, 81, 9, 2, 19);
insert into PREDA values (22, 581, 10, 3, 11);
insert into PREDA values (164, 212, 19, 2, 14);
insert into PREDA values (129, 582, 17, 3, 16);
insert into PREDA values (164, 561, 7, 4, 10);
insert into PREDA values (161, 206, 11, 1, 16);
insert into PREDA values (129, 213, 10, 5, 9);
insert into PREDA values (118, 300, 2, 4, 10);
insert into PREDA values (194, 328, 8, 3, 13);
insert into PREDA values (5, 210, 19, 4, 17);
insert into PREDA values (138, 405, 15, 1, 16);
insert into PREDA values (129, 565, 14, 2, 8);
insert into PREDA values (138, 467, 6, 3, 10);
insert into PREDA values (27, 566, 6, 2, 16);
insert into PREDA values (117, 328, 19, 4, 9);
insert into PREDA values (118, 562, 19, 5, 13);
insert into PREDA values (128, 329, 9, 2, 9);
insert into PREDA values (117, 902, 8, 5, 12);
insert into PREDA values (138, 106, 3, 4, 16);
insert into PREDA values (5, 105, 15, 2, 9);
insert into PREDA values (164, 582, 7, 4, 17);
insert into PREDA values (128, 904, 14, 5, 17);
insert into PREDA values (173, 902, 8, 3, 15);
insert into PREDA values (200, 102, 9, 1, 19);
insert into PREDA values (48, 213, 7, 2, 14);
insert into PREDA values (117, 100, 7, 4, 18);
insert into PREDA values (152, 83, 3, 1, 18);
insert into PREDA values (199, 103, 9, 4, 10);
insert into PREDA values (22, 566, 18, 2, 9);
insert into PREDA values (117, 82, 10, 2, 11);
insert into PREDA values (90, 567, 16, 2, 11);
insert into PREDA values (173, 211, 1, 4, 18);
insert into PREDA values (194, 102, 10, 5, 9);
insert into PREDA values (152, 583, 2, 2, 19);
insert into PREDA values (136, 903, 17, 3, 8);
insert into PREDA values (5, 580, 11, 2, 13);
insert into PREDA values (128, 565, 5, 4, 14);
insert into PREDA values (5, 207, 4, 3, 16);
insert into PREDA values (22, 302, 16, 3, 16);
insert into PREDA values (137, 81, 4, 4, 8);
insert into PREDA values (137, 106, 1, 4, 14);
insert into PREDA values (136, 563, 15, 1, 18);
insert into PREDA values (117, 562, 19, 4, 15);
insert into PREDA values (124, 80, 9, 2, 12);
insert into PREDA values (23, 103, 15, 3, 10);
insert into PREDA values (90, 211, 9, 2, 8);
insert into PREDA values (23, 562, 9, 3, 8);
insert into PREDA values (138, 105, 17, 1, 18);
insert into PREDA values (161, 213, 15, 3, 19);
insert into PREDA values (164, 107, 10, 3, 8);
insert into PREDA values (152, 83, 1, 2, 8);
insert into PREDA values (90, 103, 18, 3, 18);
insert into PREDA values (27, 82, 9, 5, 12);
insert into PREDA values (5, 107, 5, 2, 17);
insert into PREDA values (137, 206, 16, 4, 13);
insert into PREDA values (27, 101, 6, 5, 18);
insert into PREDA values (137, 302, 2, 1, 10);
insert into PREDA values (200, 209, 17, 3, 17);
insert into PREDA values (194, 903, 2, 2, 16);
insert into PREDA values (129, 106, 11, 4, 16);
insert into PREDA values (61, 561, 18, 2, 14);
insert into PREDA values (48, 212, 9, 1, 14);
insert into PREDA values (137, 101, 3, 3, 8);
insert into PREDA values (173, 210, 18, 3, 15);
insert into PREDA values (90, 901, 16, 2, 9);
insert into PREDA values (173, 903, 12, 5, 13);
insert into PREDA values (128, 904, 13, 2, 11);
insert into PREDA values (199, 100, 1, 2, 13);
insert into PREDA values (118, 407, 4, 1, 18);
insert into PREDA values (173, 100, 5, 2, 19);
insert into PREDA values (27, 901, 4, 4, 17);
insert into PREDA values (48, 408, 4, 5, 15);
insert into PREDA values (199, 566, 7, 1, 19);
insert into PREDA values (129, 902, 1, 3, 19);
insert into PREDA values (138, 406, 19, 4, 9);
insert into PREDA values (199, 470, 2, 1, 15);
insert into PREDA values (48, 209, 10, 4, 9);
insert into PREDA values (117, 407, 12, 1, 16);
insert into PREDA values (136, 80, 2, 2, 13);
insert into PREDA values (124, 100, 17, 3, 16);
insert into PREDA values (200, 209, 6, 4, 9);
insert into PREDA values (138, 81, 2, 4, 12);
insert into PREDA values (199, 106, 20, 3, 16);
insert into PREDA values (161, 302, 19, 3, 8);
insert into PREDA values (23, 565, 13, 1, 10);
insert into PREDA values (199, 302, 16, 4, 12);
insert into PREDA values (117, 82, 14, 4, 14);
insert into PREDA values (136, 303, 16, 4, 16);
insert into PREDA values (194, 467, 20, 1, 17);
insert into PREDA values (61, 104, 18, 3, 10);
insert into PREDA values (90, 302, 11, 3, 14);
insert into PREDA values (152, 101, 11, 4, 14);
insert into PREDA values (137, 101, 14, 1, 9);
insert into PREDA values (23, 207, 8, 1, 18);
insert into PREDA values (136, 902, 2, 1, 10);
insert into PREDA values (199, 105, 7, 1, 19);
insert into PREDA values (173, 103, 7, 1, 8);
insert into PREDA values (117, 102, 15, 5, 19);
insert into PREDA values (48, 82, 2, 4, 19);
insert into PREDA values (90, 468, 8, 3, 17);
insert into PREDA values (118, 105, 2, 3, 12);
insert into PREDA values (128, 82, 6, 3, 15);
insert into PREDA values (129, 106, 2, 2, 13);
insert into PREDA values (27, 408, 20, 5, 10);
insert into PREDA values (173, 301, 6, 3, 17);
insert into PREDA values (137, 302, 11, 4, 18);
insert into PREDA values (124, 82, 7, 2, 12);
insert into PREDA values (194, 301, 4, 4, 18);
insert into PREDA values (90, 580, 15, 2, 13);
insert into PREDA values (90, 329, 17, 5, 19);
insert into PREDA values (48, 104, 4, 4, 18);
insert into PREDA values (137, 101, 20, 2, 19);
insert into PREDA values (48, 468, 6, 3, 9);
insert into PREDA values (136, 303, 18, 2, 10);
insert into PREDA values (199, 901, 12, 4, 9);
insert into PREDA values (194, 330, 18, 5, 14);
insert into PREDA values (191, 106, 13, 4, 12);
insert into PREDA values (48, 82, 8, 5, 14);
insert into PREDA values (138, 208, 19, 4, 13);
insert into PREDA values (161, 406, 19, 1, 12);
insert into PREDA values (23, 903, 20, 2, 10);
insert into PREDA values (199, 209, 18, 4, 17);
insert into PREDA values (22, 560, 13, 3, 18);
insert into PREDA values (118, 407, 8, 5, 17);
insert into PREDA values (152, 207, 10, 3, 17);
insert into PREDA values (173, 566, 11, 1, 17);
insert into PREDA values (5, 106, 18, 2, 10);
insert into PREDA values (194, 301, 3, 3, 12);
insert into PREDA values (22, 83, 4, 1, 11);
insert into PREDA values (117, 101, 11, 3, 15);
insert into PREDA values (128, 568, 5, 1, 13);
insert into PREDA values (164, 406, 10, 1, 8);
insert into PREDA values (173, 468, 10, 4, 17);
insert into PREDA values (129, 303, 15, 3, 9);
insert into PREDA values (22, 408, 9, 4, 14);
insert into PREDA values (152, 566, 14, 1, 16);
insert into PREDA values (191, 212, 19, 3, 8);
insert into PREDA values (27, 329, 5, 2, 8);
insert into PREDA values (124, 330, 12, 4, 8);
insert into PREDA values (23, 408, 9, 3, 9);
insert into PREDA values (124, 209, 6, 2, 17);
insert into PREDA values (136, 469, 18, 4, 17);
insert into PREDA values (194, 581, 7, 5, 16);
insert into PREDA values (124, 210, 6, 4, 17);
insert into PREDA values (152, 213, 19, 3, 12);
insert into PREDA values (22, 83, 1, 4, 17);
insert into PREDA values (118, 560, 1, 3, 19);
insert into PREDA values (129, 212, 14, 5, 15);
insert into PREDA values (124, 303, 4, 4, 17);
insert into PREDA values (61, 301, 13, 4, 9);
insert into PREDA values (27, 407, 20, 4, 17);
insert into PREDA values (23, 207, 20, 4, 17);
insert into PREDA values (129, 103, 6, 4, 13);
insert into PREDA values (48, 80, 18, 2, 16);
insert into PREDA values (136, 301, 13, 3, 8);
insert into PREDA values (191, 566, 3, 3, 13);
insert into PREDA values (194, 81, 11, 3, 17);
insert into PREDA values (152, 902, 15, 4, 11);
insert into PREDA values (5, 903, 11, 2, 11);
insert into PREDA values (129, 407, 14, 3, 10);
insert into PREDA values (129, 468, 11, 2, 8);
insert into PREDA values (90, 467, 14, 1, 15);
insert into PREDA values (22, 581, 20, 5, 13);
insert into PREDA values (61, 406, 3, 4, 15);
insert into PREDA values (161, 903, 2, 2, 9);
insert into PREDA values (191, 328, 13, 3, 13);
insert into PREDA values (117, 406, 7, 5, 9);
insert into PREDA values (23, 567, 12, 5, 12);
insert into PREDA values (164, 562, 13, 2, 15);
insert into PREDA values (200, 581, 2, 3, 14);
insert into PREDA values (164, 83, 7, 1, 12);
insert into PREDA values (161, 100, 17, 2, 15);
insert into PREDA values (199, 207, 18, 5, 18);
insert into PREDA values (164, 467, 9, 3, 14);
insert into PREDA values (27, 407, 9, 1, 13);
insert into PREDA values (61, 327, 1, 4, 19);
insert into PREDA values (118, 567, 19, 2, 19);
insert into PREDA values (48, 100, 14, 1, 17);
insert into PREDA values (128, 107, 8, 2, 14);
insert into PREDA values (128, 100, 9, 5, 8);
insert into PREDA values (128, 302, 2, 2, 19);
insert into PREDA values (164, 102, 20, 5, 12);
insert into PREDA values (191, 903, 12, 1, 10);
insert into PREDA values (199, 101, 12, 4, 14);
insert into PREDA values (128, 303, 14, 4, 15);
insert into PREDA values (124, 563, 18, 3, 16);
insert into PREDA values (61, 301, 10, 2, 15);
insert into PREDA values (137, 567, 7, 5, 8);
insert into PREDA values (152, 213, 8, 2, 10);
insert into PREDA values (200, 902, 12, 5, 17);
insert into PREDA values (164, 101, 15, 5, 13);
insert into PREDA values (90, 902, 5, 3, 11);
insert into PREDA values (118, 902, 8, 1, 17);
insert into PREDA values (22, 101, 11, 4, 17);
insert into PREDA values (136, 329, 4, 5, 9);
insert into PREDA values (48, 102, 6, 1, 16);
insert into PREDA values (90, 327, 12, 4, 15);
insert into PREDA values (194, 104, 18, 5, 14);
insert into PREDA values (199, 100, 11, 3, 8);
insert into PREDA values (161, 107, 18, 1, 17);
insert into PREDA values (118, 302, 4, 3, 9);
insert into PREDA values (129, 565, 12, 3, 19);
insert into PREDA values (90, 469, 15, 2, 17);
insert into PREDA values (48, 562, 6, 3, 17);
insert into PREDA values (129, 903, 6, 4, 17);
insert into PREDA values (164, 327, 4, 2, 16);
insert into PREDA values (138, 107, 10, 5, 17);
insert into PREDA values (199, 206, 16, 5, 9);
insert into PREDA values (137, 583, 4, 5, 9);
insert into PREDA values (124, 213, 12, 4, 10);
insert into PREDA values (61, 302, 19, 4, 8);
insert into PREDA values (117, 329, 13, 3, 17);
insert into PREDA values (61, 468, 10, 5, 14);
insert into PREDA values (138, 210, 9, 5, 12);
insert into PREDA values (200, 206, 20, 3, 15);
insert into PREDA values (124, 902, 8, 1, 14);
insert into PREDA values (124, 568, 1, 1, 18);
insert into PREDA values (161, 566, 4, 5, 11);
insert into PREDA values (22, 210, 20, 1, 10);
insert into PREDA values (161, 213, 5, 3, 10);
insert into PREDA values (136, 81, 14, 1, 19);
insert into PREDA values (129, 567, 1, 3, 11);
insert into PREDA values (117, 470, 6, 5, 15);
insert into PREDA values (136, 207, 16, 5, 9);
insert into PREDA values (200, 103, 15, 4, 14);
insert into PREDA values (173, 80, 7, 5, 11);
insert into PREDA values (194, 405, 2, 2, 13);
insert into PREDA values (61, 100, 19, 1, 11);
insert into PREDA values (124, 100, 11, 1, 10);
insert into PREDA values (27, 300, 5, 5, 14);
insert into PREDA values (161, 580, 11, 1, 17);
insert into PREDA values (124, 904, 7, 3, 10);
insert into PREDA values (199, 302, 14, 4, 18);
insert into PREDA values (199, 581, 8, 4, 12);
insert into PREDA values (5, 301, 6, 5, 13);
insert into PREDA values (161, 581, 17, 5, 16);
insert into PREDA values (200, 566, 5, 3, 11);
insert into PREDA values (194, 467, 7, 1, 13);
insert into PREDA values (5, 106, 5, 3, 15);
insert into PREDA values (117, 211, 3, 3, 9);
insert into PREDA values (61, 329, 12, 1, 9);
insert into PREDA values (124, 469, 18, 1, 13);
insert into PREDA values (27, 330, 12, 4, 16);
insert into PREDA values (118, 407, 12, 5, 18);
insert into PREDA values (191, 83, 12, 4, 12);
insert into PREDA values (152, 562, 18, 3, 9);
insert into PREDA values (200, 582, 5, 5, 13);
insert into PREDA values (90, 102, 17, 3, 19);
insert into PREDA values (27, 103, 6, 5, 19);
insert into PREDA values (136, 209, 16, 1, 10);
insert into PREDA values (152, 209, 6, 1, 15);
insert into PREDA values (117, 407, 7, 3, 14);
insert into PREDA values (48, 300, 6, 5, 14);
insert into PREDA values (23, 102, 11, 5, 18);
insert into PREDA values (27, 107, 10, 4, 8);
insert into PREDA values (117, 106, 6, 4, 17);
insert into PREDA values (191, 903, 18, 5, 16);
insert into PREDA values (27, 80, 9, 3, 9);
insert into PREDA values (124, 568, 16, 5, 10);
insert into PREDA values (90, 213, 5, 1, 13);
insert into PREDA values (90, 581, 7, 4, 10);
insert into PREDA values (90, 904, 5, 1, 15);
insert into PREDA values (194, 100, 19, 5, 17);
insert into PREDA values (27, 81, 14, 5, 11);
insert into PREDA values (117, 901, 18, 2, 19);
insert into PREDA values (90, 469, 13, 3, 15);
insert into PREDA values (48, 300, 5, 5, 13);
insert into PREDA values (194, 103, 4, 4, 16);
insert into PREDA values (138, 565, 20, 1, 16);
insert into PREDA values (194, 470, 18, 3, 19);
insert into PREDA values (61, 407, 13, 5, 11);
insert into PREDA values (117, 303, 16, 1, 14);
insert into PREDA values (138, 105, 2, 4, 18);
insert into PREDA values (129, 903, 3, 1, 8);
insert into PREDA values (191, 81, 6, 2, 18);
insert into PREDA values (117, 330, 2, 5, 19);
insert into PREDA values (61, 207, 1, 4, 11);
insert into PREDA values (136, 467, 17, 3, 12);
insert into PREDA values (117, 209, 8, 2, 13);
insert into PREDA values (48, 406, 17, 1, 16);
insert into PREDA values (23, 330, 18, 1, 11);
insert into PREDA values (137, 405, 19, 2, 11);
insert into PREDA values (5, 470, 19, 2, 10);
insert into PREDA values (152, 303, 4, 2, 16);
insert into PREDA values (61, 902, 17, 3, 9);
insert into PREDA values (118, 210, 3, 3, 19);
insert into PREDA values (199, 208, 8, 2, 13);
insert into PREDA values (128, 208, 9, 4, 17);
insert into PREDA values (129, 213, 11, 2, 18);
insert into PREDA values (173, 208, 7, 4, 15);
insert into PREDA values (27, 581, 17, 2, 11);
insert into PREDA values (199, 405, 16, 4, 16);
insert into PREDA values (161, 901, 15, 4, 17);
insert into PREDA values (90, 207, 11, 4, 16);
insert into PREDA values (48, 563, 8, 5, 10);
insert into PREDA values (124, 106, 6, 2, 16);
insert into PREDA values (5, 901, 14, 4, 18);
insert into PREDA values (90, 82, 5, 2, 13);
insert into PREDA values (161, 902, 2, 5, 8);
insert into PREDA values (48, 583, 12, 4, 12);
insert into PREDA values (136, 467, 13, 5, 13);
insert into PREDA values (152, 81, 12, 1, 19);
insert into PREDA values (90, 211, 19, 2, 11);
insert into PREDA values (27, 329, 13, 3, 10);
insert into PREDA values (48, 209, 9, 3, 16);
insert into PREDA values (161, 470, 10, 4, 9);
insert into PREDA values (152, 81, 1, 2, 11);
insert into PREDA values (136, 210, 18, 1, 18);
insert into PREDA values (200, 470, 12, 1, 14);
insert into PREDA values (191, 562, 16, 1, 13);
insert into PREDA values (117, 211, 15, 5, 19);
insert into PREDA values (61, 406, 1, 4, 14);
insert into PREDA values (129, 468, 2, 4, 19);
insert into PREDA values (48, 467, 16, 3, 17);
insert into PREDA values (118, 103, 11, 1, 8);
insert into PREDA values (136, 470, 12, 1, 12);
insert into PREDA values (129, 107, 19, 5, 12);
insert into PREDA values (5, 83, 5, 2, 15);
insert into PREDA values (23, 302, 8, 3, 9);
insert into PREDA values (199, 210, 14, 5, 10);
insert into PREDA values (194, 901, 3, 4, 19);
insert into PREDA values (124, 303, 17, 4, 11);
insert into PREDA values (27, 301, 11, 2, 12);
insert into PREDA values (23, 580, 17, 1, 14);
insert into PREDA values (138, 208, 20, 3, 17);
insert into PREDA values (90, 303, 5, 4, 12);
insert into PREDA values (5, 209, 19, 4, 19);
insert into PREDA values (173, 207, 6, 2, 19);
insert into PREDA values (152, 81, 20, 2, 8);
insert into PREDA values (137, 213, 3, 2, 9);
insert into PREDA values (61, 105, 14, 3, 16);
insert into PREDA values (161, 583, 11, 4, 16);
insert into PREDA values (90, 330, 2, 1, 13);
insert into PREDA values (194, 103, 16, 2, 9);
insert into PREDA values (124, 107, 10, 4, 17);
insert into PREDA values (5, 82, 10, 4, 8);
insert into PREDA values (161, 212, 16, 5, 11);
insert into PREDA values (164, 467, 4, 3, 10);
insert into PREDA values (173, 211, 20, 3, 18);
insert into PREDA values (61, 210, 4, 1, 17);
insert into PREDA values (124, 563, 2, 5, 15);
insert into PREDA values (5, 327, 12, 2, 12);
insert into PREDA values (137, 330, 4, 3, 12);
insert into PREDA values (164, 105, 7, 3, 19);
insert into PREDA values (136, 328, 17, 1, 17);
insert into PREDA values (61, 560, 19, 3, 11);
insert into PREDA values (194, 80, 5, 1, 15);
insert into PREDA values (194, 566, 19, 1, 13);
insert into PREDA values (117, 106, 12, 5, 14);
insert into PREDA values (191, 206, 4, 2, 15);
insert into PREDA values (128, 467, 17, 4, 17);
insert into PREDA values (124, 903, 14, 5, 12);
insert into PREDA values (90, 568, 16, 2, 15);
insert into PREDA values (137, 208, 13, 5, 8);
insert into PREDA values (173, 207, 19, 4, 8);
insert into PREDA values (90, 80, 3, 1, 11);
insert into PREDA values (27, 580, 12, 3, 10);
insert into PREDA values (161, 100, 4, 2, 18);
insert into PREDA values (117, 329, 10, 4, 13);
insert into PREDA values (129, 562, 3, 5, 13);
insert into PREDA values (137, 561, 11, 5, 13);
insert into PREDA values (129, 102, 19, 2, 10);
insert into PREDA values (27, 301, 6, 1, 19);
insert into PREDA values (138, 406, 16, 3, 10);
insert into PREDA values (137, 211, 7, 3, 13);
insert into PREDA values (90, 207, 10, 5, 16);
insert into PREDA values (124, 209, 10, 2, 17);
insert into PREDA values (22, 301, 14, 5, 16);
insert into PREDA values (138, 101, 12, 5, 14);
insert into PREDA values (124, 468, 9, 4, 12);
insert into PREDA values (27, 327, 9, 3, 8);
insert into PREDA values (90, 83, 16, 4, 12);
insert into PREDA values (161, 327, 14, 1, 8);
insert into PREDA values (161, 302, 3, 2, 19);
insert into PREDA values (194, 902, 16, 3, 19);
insert into PREDA values (48, 301, 12, 3, 16);
insert into PREDA values (164, 80, 11, 2, 18);
insert into PREDA values (194, 562, 6, 5, 16);
insert into PREDA values (164, 209, 16, 1, 13);
insert into PREDA values (23, 107, 11, 5, 13);
insert into PREDA values (5, 302, 1, 3, 13);
insert into PREDA values (173, 100, 14, 2, 18);
insert into PREDA values (61, 104, 20, 3, 8);
insert into PREDA values (161, 107, 3, 2, 14);
insert into PREDA values (152, 904, 9, 3, 15);
insert into PREDA values (199, 468, 15, 5, 9);
insert into PREDA values (191, 580, 15, 3, 15);
insert into PREDA values (128, 209, 6, 5, 9);
insert into PREDA values (200, 563, 15, 3, 13);
insert into PREDA values (124, 901, 15, 1, 16);
insert into PREDA values (27, 567, 14, 2, 15);
insert into PREDA values (118, 107, 10, 5, 14);
insert into PREDA values (118, 207, 13, 4, 17);
insert into PREDA values (194, 104, 13, 4, 19);
insert into PREDA values (200, 105, 5, 3, 17);
insert into PREDA values (22, 583, 16, 1, 18);
insert into PREDA values (129, 301, 20, 3, 8);
insert into PREDA values (90, 102, 7, 3, 11);
insert into PREDA values (124, 470, 18, 1, 9);
insert into PREDA values (199, 330, 17, 1, 10);
insert into PREDA values (27, 901, 3, 1, 12);
insert into PREDA values (128, 104, 11, 3, 16);
insert into PREDA values (61, 101, 1, 2, 14);
insert into PREDA values (128, 104, 7, 3, 8);
insert into PREDA values (61, 561, 15, 2, 16);
insert into PREDA values (194, 208, 20, 4, 18);
insert into PREDA values (191, 560, 18, 5, 14);
insert into PREDA values (200, 904, 17, 3, 11);
insert into PREDA values (61, 327, 4, 4, 17);
insert into PREDA values (90, 561, 3, 1, 17);
insert into PREDA values (191, 327, 8, 4, 19);
insert into PREDA values (90, 80, 16, 3, 10);
insert into PREDA values (117, 582, 3, 3, 13);
insert into PREDA values (161, 468, 3, 3, 11);
insert into PREDA values (194, 105, 8, 5, 15);
insert into PREDA values (117, 327, 14, 3, 15);
insert into PREDA values (90, 904, 2, 2, 17);
insert into PREDA values (136, 208, 11, 3, 8);
insert into PREDA values (137, 330, 11, 2, 17);
insert into PREDA values (194, 562, 20, 2, 13);
insert into PREDA values (129, 328, 6, 4, 9);
insert into PREDA values (136, 580, 13, 2, 10);
insert into PREDA values (194, 104, 15, 4, 10);
insert into PREDA values (128, 101, 5, 2, 13);
insert into PREDA values (136, 210, 5, 4, 18);
insert into PREDA values (118, 107, 20, 4, 8);
insert into PREDA values (152, 106, 3, 2, 11);
insert into PREDA values (118, 104, 15, 1, 19);
insert into PREDA values (164, 207, 14, 4, 13);
insert into PREDA values (61, 469, 8, 5, 18);
insert into PREDA values (117, 212, 2, 2, 19);
insert into PREDA values (137, 300, 4, 4, 18);
insert into PREDA values (23, 580, 20, 2, 18);
insert into PREDA values (152, 567, 19, 3, 11);
insert into PREDA values (137, 208, 15, 2, 15);
insert into PREDA values (124, 904, 14, 1, 8);
insert into PREDA values (137, 213, 19, 2, 9);
insert into PREDA values (194, 206, 17, 1, 8);
insert into PREDA values (22, 901, 8, 4, 8);
insert into PREDA values (128, 107, 7, 2, 16);
insert into PREDA values (27, 468, 17, 1, 15);
insert into PREDA values (48, 581, 8, 5, 15);
insert into PREDA values (90, 329, 8, 4, 11);
insert into PREDA values (124, 563, 10, 3, 19);
insert into PREDA values (118, 470, 14, 4, 8);
insert into PREDA values (117, 407, 6, 4, 18);
insert into PREDA values (173, 100, 15, 5, 15);
insert into PREDA values (27, 568, 15, 1, 13);
insert into PREDA values (136, 105, 11, 3, 19);
insert into PREDA values (118, 103, 20, 5, 19);
insert into PREDA values (161, 560, 18, 4, 8);
insert into PREDA values (48, 211, 17, 4, 11);
insert into PREDA values (5, 102, 1, 3, 8);
insert into PREDA values (200, 301, 4, 1, 14);
insert into PREDA values (27, 580, 13, 2, 19);
insert into PREDA values (136, 468, 2, 5, 18);
insert into PREDA values (191, 83, 14, 2, 8);
insert into PREDA values (118, 303, 7, 5, 10);
insert into PREDA values (191, 408, 1, 3, 19);
insert into PREDA values (118, 206, 4, 1, 18);
insert into PREDA values (200, 562, 20, 2, 19);
insert into PREDA values (194, 901, 16, 3, 13);
insert into PREDA values (5, 583, 7, 2, 15);
insert into PREDA values (118, 904, 11, 2, 19);
insert into PREDA values (136, 583, 4, 5, 18);
insert into PREDA values (152, 212, 18, 3, 11);
insert into PREDA values (164, 583, 5, 2, 15);
insert into PREDA values (23, 210, 19, 1, 8);
insert into PREDA values (191, 568, 14, 1, 14);
insert into PREDA values (129, 212, 9, 4, 15);
insert into PREDA values (124, 406, 17, 5, 16);
insert into PREDA values (5, 563, 4, 4, 18);
insert into PREDA values (48, 468, 5, 2, 14);
insert into PREDA values (136, 565, 13, 5, 16);
insert into PREDA values (152, 406, 6, 4, 13);
insert into PREDA values (22, 208, 13, 1, 15);
insert into PREDA values (90, 583, 10, 5, 8);
insert into PREDA values (200, 107, 5, 5, 18);
insert into PREDA values (48, 560, 19, 1, 11);
insert into PREDA values (124, 209, 5, 3, 16);
insert into PREDA values (129, 561, 18, 4, 16);
insert into PREDA values (124, 103, 10, 5, 13);
insert into PREDA values (124, 102, 18, 2, 12);
insert into PREDA values (48, 406, 1, 4, 13);
insert into PREDA values (118, 101, 7, 4, 19);
insert into PREDA values (48, 561, 4, 5, 15);
insert into PREDA values (22, 102, 11, 1, 12);
insert into PREDA values (23, 408, 6, 2, 9);
insert into PREDA values (90, 82, 18, 2, 16);
insert into PREDA values (48, 106, 12, 3, 19);
insert into PREDA values (48, 107, 16, 1, 11);
insert into PREDA values (161, 407, 6, 5, 17);
insert into PREDA values (199, 301, 15, 2, 19);
insert into PREDA values (200, 209, 16, 5, 8);
insert into PREDA values (199, 101, 11, 5, 11);
insert into PREDA values (137, 303, 7, 2, 15);
insert into PREDA values (5, 101, 15, 1, 10);
insert into PREDA values (61, 82, 9, 1, 15);
insert into PREDA values (129, 100, 6, 3, 19);
insert into PREDA values (173, 903, 15, 4, 15);
insert into PREDA values (118, 301, 15, 1, 13);
insert into PREDA values (27, 467, 12, 1, 16);
insert into PREDA values (128, 560, 10, 1, 8);
insert into PREDA values (164, 567, 17, 1, 13);
insert into PREDA values (173, 106, 1, 1, 16);
insert into PREDA values (173, 213, 11, 3, 9);
insert into PREDA values (5, 582, 18, 1, 11);
insert into PREDA values (90, 406, 10, 2, 16);
insert into PREDA values (173, 567, 7, 3, 14);
insert into PREDA values (90, 580, 10, 2, 14);
insert into PREDA values (161, 406, 2, 5, 19);
insert into PREDA values (27, 902, 11, 3, 12);
insert into PREDA values (90, 209, 16, 5, 10);
insert into PREDA values (23, 581, 12, 1, 11);
insert into PREDA values (48, 300, 15, 1, 18);
insert into PREDA values (199, 303, 16, 1, 12);
insert into PREDA values (90, 301, 5, 2, 16);
insert into PREDA values (124, 568, 9, 2, 10);
insert into PREDA values (27, 101, 18, 4, 9);
insert into PREDA values (137, 301, 15, 5, 13);
insert into PREDA values (128, 206, 2, 5, 11);
insert into PREDA values (152, 467, 15, 5, 15);
insert into PREDA values (137, 301, 7, 3, 11);
insert into PREDA values (22, 208, 8, 2, 8);
insert into PREDA values (199, 470, 6, 3, 9);
insert into PREDA values (152, 904, 16, 2, 16);
insert into PREDA values (118, 107, 8, 5, 17);
insert into PREDA values (138, 901, 19, 1, 15);
insert into PREDA values (128, 468, 16, 5, 10);
insert into PREDA values (152, 209, 1, 5, 18);
insert into PREDA values (199, 470, 13, 5, 15);
insert into PREDA values (48, 408, 18, 4, 19);
insert into PREDA values (27, 328, 3, 3, 9);
insert into PREDA values (23, 81, 15, 4, 8);
insert into PREDA values (161, 901, 13, 4, 11);
insert into PREDA values (137, 567, 6, 5, 15);
insert into PREDA values (199, 330, 16, 2, 19);
insert into PREDA values (61, 103, 11, 4, 11);
insert into PREDA values (23, 207, 18, 5, 10);
insert into PREDA values (200, 100, 10, 4, 18);
insert into PREDA values (136, 103, 1, 2, 18);
insert into PREDA values (191, 80, 10, 5, 16);
insert into PREDA values (136, 469, 13, 2, 11);
insert into PREDA values (136, 468, 9, 2, 13);
insert into PREDA values (152, 469, 2, 2, 10);
insert into PREDA values (194, 329, 7, 2, 18);
insert into PREDA values (129, 105, 14, 5, 18);
insert into PREDA values (22, 470, 8, 3, 16);
insert into PREDA values (199, 903, 19, 2, 9);
insert into PREDA values (152, 580, 13, 5, 10);
insert into PREDA values (191, 106, 10, 2, 15);
insert into PREDA values (191, 581, 9, 1, 19);
insert into PREDA values (128, 470, 11, 4, 17);
insert into PREDA values (5, 101, 5, 3, 9);
insert into PREDA values (161, 104, 11, 2, 9);
insert into PREDA values (138, 563, 13, 4, 8);
insert into PREDA values (118, 330, 16, 2, 17);
insert into PREDA values (173, 561, 15, 4, 18);
insert into PREDA values (129, 82, 7, 4, 19);
insert into PREDA values (152, 327, 19, 2, 18);
insert into PREDA values (5, 328, 2, 4, 15);
insert into PREDA values (137, 206, 11, 5, 18);
insert into PREDA values (164, 562, 3, 4, 13);
insert into PREDA values (22, 470, 20, 2, 14);
insert into PREDA values (48, 566, 15, 4, 13);
insert into PREDA values (164, 213, 16, 2, 11);
insert into PREDA values (152, 107, 20, 5, 17);
insert into PREDA values (138, 901, 9, 2, 10);
insert into PREDA values (138, 565, 11, 3, 15);
insert into PREDA values (48, 102, 11, 2, 10);
insert into PREDA values (5, 901, 7, 2, 10);
insert into PREDA values (194, 562, 4, 5, 16);
insert into PREDA values (200, 901, 9, 5, 9);
insert into PREDA values (117, 467, 14, 4, 10);
insert into PREDA values (173, 107, 13, 4, 14);
insert into PREDA values (117, 106, 4, 1, 18);
insert into PREDA values (138, 212, 11, 5, 13);
insert into PREDA values (194, 302, 3, 1, 16);
insert into PREDA values (129, 405, 6, 2, 18);
insert into PREDA values (191, 561, 14, 2, 8);
insert into PREDA values (22, 580, 10, 5, 8);
insert into PREDA values (124, 104, 8, 2, 11);
insert into PREDA values (90, 102, 9, 2, 11);
insert into PREDA values (23, 405, 19, 5, 13);
insert into PREDA values (124, 83, 13, 4, 19);
insert into PREDA values (152, 407, 12, 2, 16);
insert into PREDA values (48, 100, 7, 1, 8);
insert into PREDA values (138, 560, 11, 1, 13);
insert into PREDA values (90, 469, 12, 3, 15);
insert into PREDA values (23, 300, 5, 1, 11);
insert into PREDA values (124, 563, 6, 3, 18);
insert into PREDA values (161, 469, 15, 1, 19);
insert into PREDA values (129, 329, 10, 2, 19);
insert into PREDA values (152, 212, 8, 2, 12);
insert into PREDA values (129, 83, 14, 1, 13);
insert into PREDA values (161, 582, 16, 5, 9);
insert into PREDA values (137, 210, 10, 1, 10);
insert into PREDA values (164, 80, 16, 3, 18);
insert into PREDA values (27, 303, 13, 2, 11);
insert into PREDA values (48, 563, 10, 5, 14);
insert into PREDA values (194, 560, 19, 3, 16);
insert into PREDA values (136, 103, 5, 5, 15);
insert into PREDA values (128, 469, 9, 2, 12);
insert into PREDA values (136, 902, 10, 2, 8);
insert into PREDA values (136, 470, 16, 1, 18);
insert into PREDA values (164, 563, 16, 4, 13);
insert into PREDA values (22, 565, 12, 2, 13);
insert into PREDA values (124, 902, 18, 3, 17);
insert into PREDA values (118, 302, 8, 4, 16);
insert into PREDA values (61, 408, 13, 4, 8);
insert into PREDA values (118, 565, 5, 2, 19);
insert into PREDA values (48, 583, 17, 4, 16);
insert into PREDA values (173, 303, 20, 5, 18);
insert into PREDA values (23, 583, 4, 5, 17);
insert into PREDA values (27, 470, 17, 1, 19);
insert into PREDA values (194, 469, 5, 5, 19);
insert into PREDA values (23, 408, 16, 3, 13);
insert into PREDA values (138, 582, 1, 5, 8);
insert into PREDA values (164, 567, 12, 2, 14);
insert into PREDA values (136, 583, 11, 3, 13);
insert into PREDA values (191, 406, 2, 3, 15);
insert into PREDA values (61, 207, 15, 1, 13);
insert into PREDA values (27, 567, 11, 3, 18);
insert into PREDA values (27, 561, 9, 4, 15);
insert into PREDA values (22, 563, 13, 5, 19);
insert into PREDA values (5, 568, 10, 2, 15);
insert into PREDA values (191, 330, 10, 4, 13);
insert into PREDA values (191, 561, 18, 4, 12);
insert into PREDA values (117, 330, 8, 4, 16);
insert into PREDA values (61, 100, 17, 5, 12);
insert into PREDA values (48, 468, 11, 3, 18);
insert into PREDA values (152, 206, 16, 5, 8);
insert into PREDA values (164, 901, 5, 1, 14);
insert into PREDA values (117, 107, 14, 1, 15);
insert into PREDA values (90, 568, 12, 4, 10);
insert into PREDA values (27, 901, 13, 4, 18);
insert into PREDA values (194, 468, 13, 3, 13);
insert into PREDA values (128, 100, 20, 3, 17);
insert into PREDA values (137, 405, 17, 5, 9);
insert into PREDA values (129, 206, 18, 5, 10);
insert into PREDA values (200, 100, 2, 4, 9);
insert into PREDA values (27, 468, 8, 2, 14);
insert into PREDA values (152, 213, 11, 1, 17);
insert into PREDA values (191, 100, 6, 5, 8);
insert into PREDA values (164, 563, 4, 2, 10);
insert into PREDA values (117, 580, 18, 5, 11);
insert into PREDA values (137, 580, 7, 1, 13);
insert into PREDA values (129, 583, 11, 5, 8);
insert into PREDA values (138, 82, 2, 5, 14);
insert into PREDA values (200, 902, 8, 5, 12);
insert into PREDA values (124, 209, 16, 2, 19);
insert into PREDA values (136, 580, 12, 2, 17);
insert into PREDA values (22, 469, 1, 2, 10);
insert into PREDA values (194, 101, 8, 3, 15);
insert into PREDA values (61, 101, 7, 5, 17);
insert into PREDA values (118, 407, 13, 4, 9);
insert into PREDA values (137, 405, 12, 4, 17);
insert into PREDA values (23, 210, 12, 2, 9);
insert into PREDA values (173, 206, 12, 5, 11);
insert into PREDA values (118, 562, 15, 5, 13);
insert into PREDA values (5, 583, 12, 4, 11);
insert into PREDA values (164, 561, 2, 1, 12);
insert into PREDA values (138, 212, 15, 1, 17);
insert into PREDA values (124, 212, 2, 2, 16);
insert into PREDA values (136, 328, 14, 3, 13);
insert into PREDA values (164, 102, 17, 2, 12);
insert into PREDA values (124, 470, 7, 1, 13);
insert into PREDA values (117, 405, 20, 2, 8);
insert into PREDA values (138, 105, 4, 2, 15);
insert into PREDA values (27, 106, 2, 1, 11);
insert into PREDA values (128, 209, 3, 4, 8);
insert into PREDA values (191, 561, 20, 2, 12);
insert into PREDA values (194, 327, 11, 5, 11);
insert into PREDA values (129, 208, 8, 5, 19);
insert into PREDA values (27, 470, 14, 2, 12);
insert into PREDA values (23, 303, 11, 5, 10);
insert into PREDA values (152, 302, 6, 5, 16);
insert into PREDA values (5, 560, 15, 5, 8);
insert into PREDA values (164, 208, 9, 2, 16);
insert into PREDA values (128, 567, 2, 2, 11);
insert into PREDA values (129, 567, 13, 1, 9);
insert into PREDA values (5, 583, 5, 5, 19);
insert into PREDA values (173, 406, 3, 1, 11);
insert into PREDA values (124, 561, 4, 2, 8);
insert into PREDA values (164, 562, 5, 3, 9);
insert into PREDA values (161, 407, 8, 1, 19);
insert into PREDA values (136, 213, 17, 1, 13);
insert into PREDA values (90, 300, 18, 3, 11);
insert into PREDA values (124, 213, 4, 5, 14);
insert into PREDA values (5, 106, 16, 3, 13);
insert into PREDA values (161, 901, 1, 5, 15);
insert into PREDA values (152, 470, 7, 2, 19);
insert into PREDA values (199, 568, 9, 1, 17);
insert into PREDA values (27, 328, 14, 1, 19);
insert into PREDA values (152, 102, 4, 1, 12);
insert into PREDA values (48, 81, 15, 5, 8);
insert into PREDA values (27, 562, 1, 4, 19);
insert into PREDA values (137, 207, 20, 3, 16);
insert into PREDA values (136, 101, 17, 3, 12);
insert into PREDA values (129, 329, 4, 5, 10);
insert into PREDA values (128, 107, 4, 4, 13);
insert into PREDA values (61, 82, 2, 1, 11);
insert into PREDA values (90, 106, 2, 3, 9);
insert into PREDA values (173, 469, 3, 5, 9);
insert into PREDA values (200, 469, 11, 1, 10);
insert into PREDA values (90, 82, 15, 4, 8);
insert into PREDA values (23, 568, 9, 2, 13);
insert into PREDA values (22, 210, 9, 3, 11);
insert into PREDA values (27, 582, 15, 1, 19);
insert into PREDA values (23, 208, 13, 4, 16);
insert into PREDA values (164, 210, 15, 5, 8);
insert into PREDA values (138, 300, 12, 2, 17);
insert into PREDA values (23, 568, 12, 2, 10);
insert into PREDA values (138, 563, 2, 2, 11);
insert into PREDA values (124, 105, 7, 1, 10);
insert into PREDA values (48, 580, 6, 3, 15);
insert into PREDA values (22, 467, 4, 1, 15);
insert into PREDA values (5, 330, 3, 5, 18);
insert into PREDA values (48, 300, 2, 2, 11);
insert into PREDA values (136, 904, 8, 2, 14);
insert into PREDA values (161, 329, 14, 3, 8);
insert into PREDA values (152, 330, 15, 3, 9);
insert into PREDA values (138, 904, 3, 3, 10);
insert into PREDA values (191, 103, 11, 3, 8);
insert into PREDA values (200, 208, 3, 3, 17);
insert into PREDA values (152, 470, 19, 2, 16);
insert into PREDA values (90, 568, 15, 3, 11);
insert into PREDA values (27, 206, 15, 4, 11);
insert into PREDA values (129, 902, 17, 5, 17);
insert into PREDA values (5, 566, 10, 1, 10);
insert into PREDA values (152, 104, 19, 3, 19);
insert into PREDA values (200, 563, 13, 4, 8);
insert into PREDA values (124, 468, 4, 3, 15);
insert into PREDA values (117, 406, 6, 3, 18);
insert into PREDA values (118, 82, 2, 2, 10);
insert into PREDA values (152, 209, 20, 5, 17);
insert into PREDA values (23, 583, 5, 3, 18);
insert into PREDA values (117, 107, 2, 3, 9);
insert into PREDA values (61, 210, 5, 2, 8);
insert into PREDA values (173, 103, 5, 4, 8);
insert into PREDA values (199, 329, 4, 3, 9);
insert into PREDA values (200, 566, 17, 1, 18);
insert into PREDA values (124, 405, 4, 1, 10);
insert into PREDA values (23, 330, 17, 5, 8);
insert into PREDA values (136, 901, 4, 1, 8);
insert into PREDA values (117, 301, 17, 5, 16);
insert into PREDA values (118, 211, 8, 4, 11);
insert into PREDA values (117, 903, 17, 4, 17);
insert into PREDA values (191, 211, 10, 4, 15);
insert into PREDA values (161, 213, 4, 3, 12);
insert into PREDA values (129, 101, 18, 2, 13);
insert into PREDA values (129, 303, 10, 5, 9);
insert into PREDA values (61, 330, 19, 2, 11);
insert into PREDA values (173, 207, 13, 3, 12);
insert into PREDA values (137, 468, 20, 1, 8);
insert into PREDA values (61, 408, 6, 4, 16);
insert into PREDA values (117, 328, 10, 2, 13);
insert into PREDA values (161, 469, 16, 3, 16);
insert into PREDA values (117, 470, 11, 5, 9);
insert into PREDA values (117, 328, 20, 2, 15);
insert into PREDA values (137, 903, 15, 1, 15);
insert into PREDA values (164, 102, 16, 1, 11);
insert into PREDA values (136, 583, 7, 5, 12);
insert into PREDA values (136, 469, 4, 4, 9);
insert into PREDA values (61, 470, 13, 5, 19);
insert into PREDA values (128, 580, 12, 4, 18);
insert into PREDA values (194, 301, 20, 1, 12);
insert into PREDA values (124, 103, 6, 5, 19);
insert into PREDA values (138, 300, 9, 2, 12);
insert into PREDA values (5, 300, 16, 5, 15);
insert into PREDA values (191, 566, 2, 3, 11);
insert into PREDA values (200, 328, 6, 2, 13);
insert into PREDA values (118, 213, 14, 3, 8);
insert into PREDA values (200, 565, 9, 4, 11);
insert into PREDA values (161, 467, 8, 5, 11);
insert into PREDA values (128, 208, 13, 3, 11);
insert into PREDA values (137, 581, 14, 3, 17);
insert into PREDA values (129, 105, 13, 4, 8);
insert into PREDA values (48, 211, 11, 1, 11);
insert into PREDA values (124, 468, 8, 4, 10);
insert into PREDA values (136, 901, 20, 2, 16);
insert into PREDA values (137, 206, 8, 3, 18);
insert into PREDA values (129, 212, 16, 1, 17);
insert into PREDA values (199, 583, 19, 4, 13);
insert into PREDA values (5, 107, 12, 5, 14);
insert into PREDA values (118, 209, 13, 5, 15);
insert into PREDA values (194, 904, 15, 4, 12);
insert into PREDA values (27, 405, 11, 1, 16);
insert into PREDA values (129, 83, 15, 2, 8);
insert into PREDA values (138, 213, 11, 5, 14);
insert into PREDA values (161, 568, 3, 3, 14);
insert into PREDA values (138, 904, 13, 2, 19);
insert into PREDA values (61, 300, 6, 5, 10);
insert into PREDA values (61, 302, 11, 3, 12);
insert into PREDA values (90, 208, 8, 3, 8);
insert into PREDA values (173, 301, 18, 4, 10);
insert into PREDA values (124, 212, 17, 4, 15);
insert into PREDA values (161, 102, 17, 1, 11);
insert into PREDA values (61, 300, 14, 2, 8);
insert into PREDA values (22, 581, 11, 1, 16);
insert into PREDA values (128, 328, 11, 4, 13);

create table REALIZEAZA (
nr_matricol number(5, 0) not null, 
id_proiect number(4, 0) not null,
deadline date not null, 

constraint pk_realizeaza primary key(nr_matricol, id_proiect, deadline)
);

alter table REALIZEAZA add foreign key(nr_matricol) references ELEV(nr_matricol);
alter table REALIZEAZA add foreign key(id_proiect) references PROIECT(id_proiect);

delete from realizeaza where nr_matricol = 11400 and id_proiect = 2 and deadline = '30-12-2022';

insert into REALIZEAZA values (39499, 1, '30-12-2022');
insert into REALIZEAZA values (11400, 1, '30-12-2022');
insert into REALIZEAZA values (91508, 1, '31-12-2022');
insert into REALIZEAZA values (91566, 6, '27-03-2022');
insert into REALIZEAZA values (13200, 2, '09-01-2022');
insert into REALIZEAZA values (18177, 3, '22-03-2022');
insert into REALIZEAZA values (12276, 6, '28-10-2022');
insert into REALIZEAZA values (41056, 1, '14-09-2022');
insert into REALIZEAZA values (81354, 0, '01-04-2022');
insert into REALIZEAZA values (80557, 3, '05-06-2022');
insert into REALIZEAZA values (10575, 1, '01-09-2022');
insert into REALIZEAZA values (74535, 3, '28-06-2022');
insert into REALIZEAZA values (86053, 5, '13-09-2022');
insert into REALIZEAZA values (11702, 4, '14-08-2022');
insert into REALIZEAZA values (85575, 6, '20-02-2022');
insert into REALIZEAZA values (91463, 6, '24-02-2022');
insert into REALIZEAZA values (34763, 6, '28-11-2022');
insert into REALIZEAZA values (42980, 2, '27-07-2022');
insert into REALIZEAZA values (97724, 1, '04-02-2022');
insert into REALIZEAZA values (71447, 5, '03-05-2022');
insert into REALIZEAZA values (32887, 1, '29-08-2022');
insert into REALIZEAZA values (54270, 6, '03-01-2022');
insert into REALIZEAZA values (48303, 1, '23-12-2022');
insert into REALIZEAZA values (33279, 4, '03-12-2022');
insert into REALIZEAZA values (81003, 1, '11-10-2022');
insert into REALIZEAZA values (84475, 3, '15-04-2022');
insert into REALIZEAZA values (32651, 1, '26-06-2022');
insert into REALIZEAZA values (69929, 0, '13-11-2022');
insert into REALIZEAZA values (79989, 6, '13-07-2022');
insert into REALIZEAZA values (13931, 5, '21-05-2022');
insert into REALIZEAZA values (84498, 5, '22-10-2022');
insert into REALIZEAZA values (59573, 3, '14-09-2022');
insert into REALIZEAZA values (26503, 1, '22-11-2022');
insert into REALIZEAZA values (18580, 1, '23-01-2022');
insert into REALIZEAZA values (12019, 6, '23-04-2022');
insert into REALIZEAZA values (92504, 0, '17-07-2022');
insert into REALIZEAZA values (53388, 6, '02-09-2022');
insert into REALIZEAZA values (73805, 4, '18-08-2022');
insert into REALIZEAZA values (93378, 3, '18-12-2022');
insert into REALIZEAZA values (34763, 3, '29-05-2022');
insert into REALIZEAZA values (79243, 1, '28-10-2022');
insert into REALIZEAZA values (78878, 1, '14-01-2022');
insert into REALIZEAZA values (12276, 3, '17-02-2022');
insert into REALIZEAZA values (97706, 6, '21-05-2022');
insert into REALIZEAZA values (90430, 1, '10-03-2022');
insert into REALIZEAZA values (89489, 5, '10-07-2022');
insert into REALIZEAZA values (26989, 6, '09-12-2022');
insert into REALIZEAZA values (39639, 6, '08-02-2022');
insert into REALIZEAZA values (93071, 6, '08-09-2022');
insert into REALIZEAZA values (81003, 2, '16-06-2022');
insert into REALIZEAZA values (14991, 1, '08-11-2022');
insert into REALIZEAZA values (60725, 6, '06-07-2022');
insert into REALIZEAZA values (51581, 0, '13-02-2022');
insert into REALIZEAZA values (18177, 6, '02-10-2022');
insert into REALIZEAZA values (74966, 1, '17-02-2022');
insert into REALIZEAZA values (32887, 5, '24-02-2022');
insert into REALIZEAZA values (86053, 1, '14-04-2022');
insert into REALIZEAZA values (15269, 6, '07-06-2022');
insert into REALIZEAZA values (66790, 0, '01-01-2022');
insert into REALIZEAZA values (76700, 2, '19-01-2022');
insert into REALIZEAZA values (23455, 1, '15-04-2022');
insert into REALIZEAZA values (78084, 1, '15-03-2022');
insert into REALIZEAZA values (39499, 4, '28-07-2022');
insert into REALIZEAZA values (51581, 6, '14-01-2022');
insert into REALIZEAZA values (56729, 0, '02-08-2022');
insert into REALIZEAZA values (20134, 5, '14-03-2022');
insert into REALIZEAZA values (87780, 4, '03-12-2022');
insert into REALIZEAZA values (30730, 6, '24-07-2022');
insert into REALIZEAZA values (11594, 0, '02-09-2022');
insert into REALIZEAZA values (23455, 5, '11-08-2022');
insert into REALIZEAZA values (54270, 2, '03-01-2022');
insert into REALIZEAZA values (32932, 1, '25-05-2022');
insert into REALIZEAZA values (59829, 6, '04-11-2022');
insert into REALIZEAZA values (91566, 2, '16-03-2022');
insert into REALIZEAZA values (65045, 2, '05-12-2022');
insert into REALIZEAZA values (50327, 4, '28-08-2022');
insert into REALIZEAZA values (15687, 1, '14-03-2022');
insert into REALIZEAZA values (18177, 4, '02-11-2022');
insert into REALIZEAZA values (71224, 5, '24-07-2022');
insert into REALIZEAZA values (96162, 0, '26-02-2022');
insert into REALIZEAZA values (96342, 1, '15-06-2022');
insert into REALIZEAZA values (12930, 0, '03-08-2022');
insert into REALIZEAZA values (32932, 6, '18-10-2022');
insert into REALIZEAZA values (50210, 1, '22-07-2022');
insert into REALIZEAZA values (69300, 5, '19-10-2022');
insert into REALIZEAZA values (24529, 6, '21-10-2022');
insert into REALIZEAZA values (41915, 5, '18-11-2022');
insert into REALIZEAZA values (93748, 6, '19-02-2022');
insert into REALIZEAZA values (59755, 3, '18-12-2022');
insert into REALIZEAZA values (65744, 3, '01-10-2022');
insert into REALIZEAZA values (69300, 2, '04-07-2022');
insert into REALIZEAZA values (52379, 6, '19-02-2022');
insert into REALIZEAZA values (51581, 4, '12-06-2022');
insert into REALIZEAZA values (27827, 5, '26-11-2022');
insert into REALIZEAZA values (63531, 1, '20-01-2022');
insert into REALIZEAZA values (90430, 0, '27-10-2022');
insert into REALIZEAZA values (35283, 2, '02-05-2022');
insert into REALIZEAZA values (46821, 4, '01-12-2022');
insert into REALIZEAZA values (13931, 4, '17-07-2022');
insert into REALIZEAZA values (14991, 2, '16-04-2022');
insert into REALIZEAZA values (30730, 5, '01-02-2022');
insert into REALIZEAZA values (59054, 4, '03-01-2022');
insert into REALIZEAZA values (81003, 6, '01-04-2022');
insert into REALIZEAZA values (71224, 0, '10-03-2022');
insert into REALIZEAZA values (68054, 3, '16-06-2022');
insert into REALIZEAZA values (87892, 5, '22-08-2022');
insert into REALIZEAZA values (30736, 4, '08-03-2022');
insert into REALIZEAZA values (51056, 2, '07-06-2022');
insert into REALIZEAZA values (34961, 5, '03-06-2022');
insert into REALIZEAZA values (36123, 2, '26-06-2022');
insert into REALIZEAZA values (19274, 2, '06-01-2022');
insert into REALIZEAZA values (45754, 2, '23-07-2022');
insert into REALIZEAZA values (85447, 4, '14-05-2022');
insert into REALIZEAZA values (37880, 5, '14-03-2022');
insert into REALIZEAZA values (41915, 3, '19-09-2022');
insert into REALIZEAZA values (97724, 6, '02-08-2022');
insert into REALIZEAZA values (81244, 0, '18-08-2022');
insert into REALIZEAZA values (63531, 2, '12-06-2022');
insert into REALIZEAZA values (20134, 4, '08-03-2022');
insert into REALIZEAZA values (97724, 5, '21-05-2022');
insert into REALIZEAZA values (49858, 3, '28-01-2022');
insert into REALIZEAZA values (10575, 4, '25-03-2022');
insert into REALIZEAZA values (59573, 6, '29-05-2022');
insert into REALIZEAZA values (27827, 6, '24-06-2022');
insert into REALIZEAZA values (81244, 5, '19-08-2022');
insert into REALIZEAZA values (42853, 0, '10-04-2022');
insert into REALIZEAZA values (13200, 4, '10-04-2022');
insert into REALIZEAZA values (47168, 0, '28-12-2022');
insert into REALIZEAZA values (41542, 6, '07-07-2022');
insert into REALIZEAZA values (30730, 0, '23-09-2022');
insert into REALIZEAZA values (58035, 4, '11-06-2022');
insert into REALIZEAZA values (79107, 1, '14-04-2022');
insert into REALIZEAZA values (41542, 5, '02-11-2022');
insert into REALIZEAZA values (86601, 0, '24-11-2022');
insert into REALIZEAZA values (53992, 3, '14-09-2022');
insert into REALIZEAZA values (77928, 0, '01-03-2022');
insert into REALIZEAZA values (33279, 5, '11-04-2022');
insert into REALIZEAZA values (41915, 1, '04-11-2022');
insert into REALIZEAZA values (32651, 6, '08-08-2022');
insert into REALIZEAZA values (48303, 2, '06-08-2022');
insert into REALIZEAZA values (59054, 0, '19-01-2022');
insert into REALIZEAZA values (31898, 1, '23-12-2022');
insert into REALIZEAZA values (27911, 4, '09-09-2022');
insert into REALIZEAZA values (15269, 1, '11-05-2022');
insert into REALIZEAZA values (30497, 5, '11-11-2022');
insert into REALIZEAZA values (27827, 1, '01-08-2022');
insert into REALIZEAZA values (41050, 5, '18-10-2022');
insert into REALIZEAZA values (78878, 3, '20-09-2022');
insert into REALIZEAZA values (37156, 6, '10-04-2022');
insert into REALIZEAZA values (79308, 0, '09-07-2022');
insert into REALIZEAZA values (96342, 6, '28-04-2022');
insert into REALIZEAZA values (86601, 6, '24-03-2022');
insert into REALIZEAZA values (87780, 4, '11-01-2022');
insert into REALIZEAZA values (87780, 4, '12-01-2022');
insert into REALIZEAZA values (87780, 4, '13-01-2022');


create table PARTICIPA (
nr_matricol number(5, 0) not null,
cod_olimpiada number(5, 0) not null,
premiu number(2, 0) not null,
data_organizare date not null,

constraint pk_participa primary key(nr_matricol, cod_olimpiada)
);

alter table PARTICIPA add foreign key(nr_matricol) references ELEV(nr_matricol);
alter table PARTICIPA add foreign key(cod_olimpiada) references OLIMPIADA(cod_olimpiada);

insert into PARTICIPA values (68716, 10001, 9, '06-04-2022');
insert into PARTICIPA values (91433, 10007, 10, '12-03-2022');
insert into PARTICIPA values (71224, 10004, 4, '04-01-2022');
insert into PARTICIPA values (73805, 10001, 1, '03-11-2022');
insert into PARTICIPA values (42853, 10000, 15, '21-11-2022');
insert into PARTICIPA values (30497, 10002, 2, '03-10-2022');
insert into PARTICIPA values (48303, 10003, 17, '08-08-2022');
insert into PARTICIPA values (18580, 10001, 8, '01-01-2022');
insert into PARTICIPA values (66790, 10007, 12, '04-01-2022');
insert into PARTICIPA values (78878, 10000, 14, '14-11-2022');
insert into PARTICIPA values (32932, 10004, 13, '09-02-2022');
insert into PARTICIPA values (71886, 10008, 20, '29-03-2022');
insert into PARTICIPA values (79989, 10006, 4, '16-04-2022');
insert into PARTICIPA values (76959, 10007, 2, '11-10-2022');
insert into PARTICIPA values (91433, 10008, 3, '17-04-2022');
insert into PARTICIPA values (95640, 10003, 11, '13-04-2022');
insert into PARTICIPA values (30549, 10003, 11, '21-10-2022');
insert into PARTICIPA values (94765, 10007, 5, '05-11-2022');
insert into PARTICIPA values (79989, 10001, 18, '16-08-2022');
insert into PARTICIPA values (91463, 10001, 6, '07-01-2022');
insert into PARTICIPA values (85575, 10004, 1, '12-06-2022');
insert into PARTICIPA values (13170, 10000, 14, '12-10-2022');
insert into PARTICIPA values (36123, 10001, 17, '25-05-2022');
insert into PARTICIPA values (49349, 10001, 17, '14-11-2022');
insert into PARTICIPA values (49858, 10006, 13, '12-12-2022');
insert into PARTICIPA values (69300, 10000, 11, '05-11-2022');
insert into PARTICIPA values (71886, 10001, 6, '28-06-2022');
insert into PARTICIPA values (17661, 10007, 1, '04-06-2022');
insert into PARTICIPA values (76700, 10007, 11, '16-04-2022');
insert into PARTICIPA values (63531, 10002, 18, '03-05-2022');
insert into PARTICIPA values (34285, 10003, 6, '04-03-2022');
insert into PARTICIPA values (23630, 10007, 13, '08-02-2022');
insert into PARTICIPA values (37671, 10007, 10, '20-05-2022');
insert into PARTICIPA values (76297, 10000, 9, '07-03-2022');
insert into PARTICIPA values (50327, 10008, 10, '09-04-2022');
insert into PARTICIPA values (81003, 10007, 1, '07-01-2022');
insert into PARTICIPA values (41813, 10008, 14, '24-09-2022');
insert into PARTICIPA values (97706, 10001, 16, '02-01-2022');
insert into PARTICIPA values (70793, 10006, 20, '06-09-2022');
insert into PARTICIPA values (81003, 10002, 8, '29-12-2022');
insert into PARTICIPA values (81003, 10005, 14, '28-09-2022');
insert into PARTICIPA values (34285, 10008, 18, '03-05-2022');
insert into PARTICIPA values (92384, 10004, 18, '13-10-2022');
insert into PARTICIPA values (33279, 10008, 7, '15-12-2022');
insert into PARTICIPA values (34285, 10005, 18, '19-11-2022');
insert into PARTICIPA values (12276, 10004, 9, '02-02-2022');
insert into PARTICIPA values (71447, 10003, 11, '03-09-2022');
insert into PARTICIPA values (20134, 10000, 13, '06-12-2022');
insert into PARTICIPA values (12276, 10006, 20, '10-08-2022');
insert into PARTICIPA values (34763, 10008, 3, '20-10-2022');
insert into PARTICIPA values (33799, 10002, 1, '16-07-2022');
insert into PARTICIPA values (46821, 10008, 1, '05-02-2022');
insert into PARTICIPA values (65744, 10005, 12, '26-07-2022');
insert into PARTICIPA values (76297, 10005, 5, '08-09-2022');
insert into PARTICIPA values (53388, 10008, 8, '06-01-2022');
insert into PARTICIPA values (30549, 10006, 17, '06-08-2022');
insert into PARTICIPA values (48303, 10000, 1, '11-08-2022');
insert into PARTICIPA values (37671, 10006, 16, '20-01-2022');
insert into PARTICIPA values (49878, 10008, 20, '03-12-2022');
insert into PARTICIPA values (32887, 10002, 5, '29-11-2022');
insert into PARTICIPA values (52379, 10007, 18, '11-08-2022');
insert into PARTICIPA values (18177, 10004, 6, '18-11-2022');
insert into PARTICIPA values (50327, 10002, 4, '27-01-2022');
insert into PARTICIPA values (27022, 10007, 13, '03-11-2022');
insert into PARTICIPA values (96996, 10004, 1, '15-06-2022');
insert into PARTICIPA values (46821, 10004, 4, '17-04-2022');
insert into PARTICIPA values (84475, 10000, 8, '03-10-2022');
insert into PARTICIPA values (69929, 10002, 11, '13-06-2022');
insert into PARTICIPA values (41813, 10001, 13, '28-09-2022');
insert into PARTICIPA values (92384, 10003, 8, '12-08-2022');
insert into PARTICIPA values (33799, 10000, 12, '05-06-2022');
insert into PARTICIPA values (49878, 10001, 19, '06-05-2022');
insert into PARTICIPA values (95309, 10004, 10, '06-02-2022');
insert into PARTICIPA values (18985, 10008, 16, '06-11-2022');
insert into PARTICIPA values (51056, 10005, 10, '19-07-2022');
insert into PARTICIPA values (93748, 10007, 1, '10-09-2022');
insert into PARTICIPA values (37671, 10008, 1, '27-08-2022');
insert into PARTICIPA values (27022, 10003, 11, '21-01-2022');
insert into PARTICIPA values (41813, 10006, 6, '10-01-2022');
insert into PARTICIPA values (95309, 10001, 19, '08-01-2022');
insert into PARTICIPA values (49349, 10000, 3, '14-01-2022');
insert into PARTICIPA values (61371, 10001, 5, '19-08-2022');
insert into PARTICIPA values (68069, 10007, 12, '15-12-2022');
insert into PARTICIPA values (79243, 10004, 1, '23-02-2022');
insert into PARTICIPA values (25275, 10006, 18, '21-06-2022');
insert into PARTICIPA values (30730, 10007, 16, '25-07-2022');
insert into PARTICIPA values (81003, 10004, 6, '09-02-2022');
insert into PARTICIPA values (18580, 10005, 1, '23-02-2022');
insert into PARTICIPA values (52379, 10006, 9, '26-12-2022');
insert into PARTICIPA values (91463, 10005, 2, '18-03-2022');
insert into PARTICIPA values (15687, 10008, 14, '04-12-2022');
insert into PARTICIPA values (32129, 10007, 7, '28-05-2022');
insert into PARTICIPA values (95857, 10005, 3, '16-09-2022');
insert into PARTICIPA values (11594, 10004, 19, '03-07-2022');
insert into PARTICIPA values (96996, 10001, 3, '28-11-2022');
insert into PARTICIPA values (86557, 10008, 11, '28-02-2022');
insert into PARTICIPA values (24529, 10004, 7, '29-03-2022');
insert into PARTICIPA values (41056, 10008, 1, '12-10-2022');
insert into PARTICIPA values (10575, 10003, 4, '17-06-2022');
insert into PARTICIPA values (34285, 10000, 10, '08-02-2022');
insert into PARTICIPA values (90430, 10000, 6, '14-12-2022');
insert into PARTICIPA values (19274, 10001, 5, '22-06-2022');
insert into PARTICIPA values (69298, 10001, 18, '01-05-2022');
insert into PARTICIPA values (63531, 10008, 5, '17-09-2022');
insert into PARTICIPA values (79107, 10005, 6, '21-06-2022');
insert into PARTICIPA values (68069, 10001, 11, '12-08-2022');
insert into PARTICIPA values (39639, 10004, 12, '07-08-2022');
insert into PARTICIPA values (71224, 10000, 4, '09-05-2022');
insert into PARTICIPA values (96162, 10008, 1, '22-08-2022');
insert into PARTICIPA values (80663, 10007, 17, '26-04-2022');
insert into PARTICIPA values (93748, 10000, 4, '25-08-2022');
insert into PARTICIPA values (24529, 10003, 6, '13-03-2022');
insert into PARTICIPA values (19274, 10006, 1, '28-08-2022');
insert into PARTICIPA values (17661, 10000, 14, '16-12-2022');
insert into PARTICIPA values (67084, 10005, 1, '03-02-2022');
insert into PARTICIPA values (19274, 10007, 11, '02-11-2022');
insert into PARTICIPA values (71170, 10003, 2, '19-05-2022');
insert into PARTICIPA values (48418, 10004, 20, '04-12-2022');
insert into PARTICIPA values (86601, 10006, 1, '15-11-2022');
insert into PARTICIPA values (76959, 10008, 7, '20-10-2022');
insert into PARTICIPA values (61371, 10006, 9, '01-05-2022');
insert into PARTICIPA values (41813, 10000, 15, '22-05-2022');
insert into PARTICIPA values (30730, 10003, 8, '23-08-2022');
insert into PARTICIPA values (32887, 10007, 9, '03-02-2022');
insert into PARTICIPA values (59829, 10004, 1, '12-06-2022');
insert into PARTICIPA values (58914, 10008, 11, '16-09-2022');
insert into PARTICIPA values (76297, 10007, 12, '18-05-2022');
insert into PARTICIPA values (66790, 10005, 3, '12-03-2022');
insert into PARTICIPA values (77928, 10005, 15, '13-08-2022');
insert into PARTICIPA values (15269, 10001, 12, '11-08-2022');
insert into PARTICIPA values (61371, 10008, 3, '22-10-2022');
insert into PARTICIPA values (37156, 10000, 13, '07-10-2022');
insert into PARTICIPA values (37156, 10002, 3, '19-11-2022');
insert into PARTICIPA values (15269, 10002, 16, '14-01-2022');
insert into PARTICIPA values (10575, 10004, 1, '06-10-2022');
insert into PARTICIPA values (81354, 10007, 15, '26-11-2022');
insert into PARTICIPA values (71886, 10002, 3, '11-11-2022');
insert into PARTICIPA values (56729, 10000, 9, '04-02-2022');
insert into PARTICIPA values (12276, 10002, 16, '13-03-2022');
insert into PARTICIPA values (15269, 10003, 17, '14-11-2022');
insert into PARTICIPA values (95857, 10004, 5, '26-07-2022');
insert into PARTICIPA values (93071, 10002, 1, '26-03-2022');
insert into PARTICIPA values (30736, 10008, 17, '08-01-2022');
insert into PARTICIPA values (49349, 10003, 11, '14-05-2022');
insert into PARTICIPA values (37250, 10006, 1, '28-07-2022');
insert into PARTICIPA values (27720, 10006, 14, '28-12-2022');
insert into PARTICIPA values (87780, 10001, 1, '02-03-2022');
insert into PARTICIPA values (67084, 10007, 5, '05-07-2022');
insert into PARTICIPA values (32651, 10001, 7, '22-06-2022');
insert into PARTICIPA values (53388, 10002, 18, '09-02-2022');
insert into PARTICIPA values (44366, 10003, 20, '04-09-2022');
insert into PARTICIPA values (34285, 10002, 16, '10-03-2022');
insert into PARTICIPA values (61371, 10000, 15, '04-09-2022');
insert into PARTICIPA values (92384, 10001, 19, '19-10-2022');
insert into PARTICIPA values (84873, 10004, 18, '07-01-2022');
insert into PARTICIPA values (37880, 10008, 11, '21-08-2022');
insert into PARTICIPA values (13200, 10003, 8, '02-12-2022');
insert into PARTICIPA values (52047, 10007, 18, '08-12-2022');
insert into PARTICIPA values (23630, 10005, 4, '11-10-2022');
insert into PARTICIPA values (23455, 10002, 2, '08-09-2022');
insert into PARTICIPA values (56729, 10001, 13, '17-06-2022');
insert into PARTICIPA values (32651, 10008, 13, '08-04-2022');
insert into PARTICIPA values (58914, 10000, 4, '23-12-2022');
insert into PARTICIPA values (65045, 10002, 17, '20-02-2022');
insert into PARTICIPA values (50327, 10007, 6, '12-08-2022');
insert into PARTICIPA values (63531, 10007, 16, '27-12-2022');
insert into PARTICIPA values (34763, 10000, 2, '13-10-2022');
insert into PARTICIPA values (49878, 10002, 17, '28-11-2022');
insert into PARTICIPA values (17661, 10003, 10, '22-06-2022');
insert into PARTICIPA values (60798, 10005, 13, '12-08-2022');
insert into PARTICIPA values (96342, 10003, 13, '18-06-2022');
insert into PARTICIPA values (26503, 10005, 20, '28-12-2022');
insert into PARTICIPA values (99911, 10006, 16, '18-04-2022');
insert into PARTICIPA values (92384, 10005, 18, '16-04-2022');
insert into PARTICIPA values (41056, 10007, 8, '11-12-2022');
insert into PARTICIPA values (99911, 10007, 11, '22-04-2022');
insert into PARTICIPA values (20134, 10002, 13, '01-08-2022');
insert into PARTICIPA values (50327, 10006, 18, '21-02-2022');
insert into PARTICIPA values (52047, 10005, 17, '12-04-2022');
insert into PARTICIPA values (49858, 10004, 2, '23-04-2022');
insert into PARTICIPA values (95857, 10007, 7, '20-06-2022');
insert into PARTICIPA values (59321, 10003, 1, '22-01-2022');
insert into PARTICIPA values (10575, 10008, 11, '05-10-2022');
insert into PARTICIPA values (23630, 10001, 12, '09-09-2022');
insert into PARTICIPA values (82246, 10002, 19, '13-02-2022');
insert into PARTICIPA values (71886, 10007, 11, '08-01-2022');
insert into PARTICIPA values (37671, 10005, 3, '27-12-2022');
insert into PARTICIPA values (34008, 10008, 8, '27-02-2022');
insert into PARTICIPA values (19852, 10004, 15, '22-06-2022');
insert into PARTICIPA values (30549, 10000, 7, '06-10-2022');
insert into PARTICIPA values (93071, 10001, 9, '16-05-2022');
insert into PARTICIPA values (78084, 10000, 12, '20-05-2022');
insert into PARTICIPA values (84498, 10006, 15, '01-01-2022');
insert into PARTICIPA values (27720, 10002, 15, '08-12-2022');
insert into PARTICIPA values (97706, 10004, 16, '22-01-2022');
insert into PARTICIPA values (65744, 10004, 14, '11-04-2022');
insert into PARTICIPA values (15269, 10000, 3, '28-09-2022');
insert into PARTICIPA values (32651, 10007, 18, '09-12-2022');
insert into PARTICIPA values (12276, 10003, 1, '01-03-2022');
insert into PARTICIPA values (59573, 10007, 14, '26-07-2022');

create table TIP_NOTA (
nume varchar2(25) not null primary key,
importanta number(1, 0) not null
);

insert into TIP_NOTA values ('examen', 1);
insert into TIP_NOTA values ('teza', 2);
insert into TIP_NOTA values ('evaluare finala', 3);
insert into TIP_NOTA values ('evaluare', 4);
insert into TIP_NOTA values ('test', 5);
insert into TIP_NOTA values ('activitate independenta', 6);

create table NOTA (
id_nota number(6, 0) not null primary key,
nume varchar2(25) not null,
nr_matricol number(5, 0) not null,
id_materie number(2, 0) not null,
data_notarii date not null, 
calificativ number(3, 1) not null,

foreign key(nume) references TIP_NOTA(nume),
foreign key(nr_matricol) references ELEV(nr_matricol),
foreign key(id_materie) references MATERIE(id_materie)
);

insert into NOTA values (568, 'test', 71224, 9, '20-05-2022', 10);
insert into NOTA values (1338, 'activitate independenta', 80557, 13, '07-12-2022', 9);
insert into NOTA values (1481, 'test', 59573, 19, '25-09-2022', 7);
insert into NOTA values (1071, 'teza', 65478, 3, '18-10-2022', 8);
insert into NOTA values (1503, 'teza', 59573, 13, '19-08-2022', 8);
insert into NOTA values (1377, 'activitate independenta', 95640, 19, '17-08-2022', 8);
insert into NOTA values (412, 'evaluare finala', 37880, 5, '10-07-2022', 8);
insert into NOTA values (116, 'evaluare', 25275, 6, '12-07-2022', 6);
insert into NOTA values (329, 'evaluare finala', 49858, 1, '04-08-2022', 2);
insert into NOTA values (696, 'evaluare finala', 26599, 13, '03-08-2022', 8);
insert into NOTA values (1648, 'teza', 42980, 17, '16-07-2022', 4);
insert into NOTA values (107, 'test', 91566, 4, '15-06-2022', 5);
insert into NOTA values (918, 'evaluare finala', 26599, 20, '12-02-2022', 9);
insert into NOTA values (99, 'evaluare finala', 66790, 18, '01-08-2022', 5);
insert into NOTA values (1415, 'examen', 23630, 16, '26-07-2022', 7);
insert into NOTA values (1657, 'evaluare finala', 13170, 13, '24-09-2022', 9);
insert into NOTA values (1202, 'evaluare', 37725, 1, '03-05-2022', 4);
insert into NOTA values (18, 'evaluare finala', 86557, 19, '16-05-2022', 5);
insert into NOTA values (1230, 'test', 91433, 7, '11-11-2022', 1);
insert into NOTA values (1126, 'activitate independenta', 84498, 1, '07-07-2022', 6);
insert into NOTA values (704, 'examen', 30549, 17, '07-05-2022', 1);
insert into NOTA values (1980, 'teza', 94765, 16, '16-02-2022', 9);
insert into NOTA values (1929, 'examen', 65744, 4, '22-05-2022', 3);
insert into NOTA values (287, 'evaluare finala', 32651, 17, '16-04-2022', 3);
insert into NOTA values (501, 'examen', 34285, 7, '21-02-2022', 7);
insert into NOTA values (547, 'examen', 96996, 19, '01-07-2022', 1);
insert into NOTA values (113, 'examen', 48303, 3, '16-11-2022', 1);
insert into NOTA values (137, 'evaluare finala', 41542, 6, '20-04-2022', 5);
insert into NOTA values (1863, 'examen', 52700, 2, '20-12-2022', 8);
insert into NOTA values (1525, 'evaluare', 32129, 1, '29-07-2022', 5);
insert into NOTA values (1647, 'activitate independenta', 18136, 6, '13-02-2022', 7);
insert into NOTA values (1254, 'evaluare finala', 24529, 2, '23-03-2022', 2);
insert into NOTA values (1754, 'test', 77632, 17, '13-07-2022', 4);
insert into NOTA values (1568, 'evaluare finala', 95857, 1, '22-04-2022', 9);
insert into NOTA values (671, 'evaluare', 85447, 8, '25-03-2022', 8);
insert into NOTA values (1831, 'examen', 27827, 19, '01-04-2022', 5);
insert into NOTA values (303, 'teza', 79243, 9, '09-05-2022', 9);
insert into NOTA values (1241, 'evaluare finala', 37725, 9, '14-08-2022', 4);
insert into NOTA values (1059, 'teza', 85447, 9, '11-03-2022', 10);
insert into NOTA values (401, 'activitate independenta', 69929, 1, '25-06-2022', 7);
insert into NOTA values (393, 'test', 53992, 1, '16-02-2022', 2);
insert into NOTA values (241, 'examen', 71886, 6, '14-04-2022', 4);
insert into NOTA values (1787, 'examen', 92504, 3, '09-04-2022', 6);
insert into NOTA values (1689, 'evaluare', 27022, 10, '23-08-2022', 1);
insert into NOTA values (1317, 'evaluare finala', 51581, 7, '01-11-2022', 9);
insert into NOTA values (1533, 'activitate independenta', 36123, 14, '02-05-2022', 9);
insert into NOTA values (219, 'activitate independenta', 37880, 17, '05-06-2022', 2);
insert into NOTA values (631, 'teza', 95188, 11, '02-12-2022', 6);
insert into NOTA values (252, 'activitate independenta', 93748, 6, '11-11-2022', 3);
insert into NOTA values (976, 'test', 70793, 14, '02-04-2022', 1);
insert into NOTA values (1186, 'test', 37156, 18, '23-11-2022', 10);
insert into NOTA values (12, 'teza', 93071, 4, '19-04-2022', 8);
insert into NOTA values (1888, 'evaluare finala', 41542, 14, '20-04-2022', 9);
insert into NOTA values (884, 'teza', 33799, 14, '26-06-2022', 3);
insert into NOTA values (714, 'examen', 52047, 17, '19-10-2022', 1);
insert into NOTA values (721, 'teza', 87892, 7, '13-10-2022', 5);
insert into NOTA values (589, 'evaluare finala', 42853, 12, '27-02-2022', 8);
insert into NOTA values (1660, 'test', 30736, 19, '09-02-2022', 1);
insert into NOTA values (1982, 'examen', 20449, 13, '19-02-2022', 2);
insert into NOTA values (73, 'test', 93071, 3, '10-12-2022', 6);
insert into NOTA values (3, 'evaluare finala', 35731, 16, '12-04-2022', 3);
insert into NOTA values (1849, 'examen', 24529, 8, '12-01-2022', 9);
insert into NOTA values (734, 'test', 85575, 16, '22-11-2022', 6);
insert into NOTA values (1506, 'activitate independenta', 81354, 8, '27-10-2022', 6);
insert into NOTA values (1346, 'examen', 33799, 6, '17-08-2022', 7);
insert into NOTA values (1319, 'evaluare finala', 84498, 1, '02-12-2022', 5);
insert into NOTA values (1597, 'evaluare finala', 96342, 2, '24-04-2022', 4);
insert into NOTA values (500, 'test', 30730, 14, '11-05-2022', 10);
insert into NOTA values (1784, 'teza', 58540, 2, '11-07-2022', 3);
insert into NOTA values (1424, 'evaluare finala', 74535, 4, '03-12-2022', 6);
insert into NOTA values (157, 'test', 69929, 9, '13-01-2022', 4);
insert into NOTA values (1104, 'activitate independenta', 68054, 4, '19-03-2022', 4);
insert into NOTA values (397, 'examen', 86601, 8, '19-07-2022', 5);
insert into NOTA values (1809, 'evaluare', 73805, 20, '08-12-2022', 3);
insert into NOTA values (781, 'examen', 78084, 10, '27-06-2022', 2);
insert into NOTA values (504, 'examen', 33279, 13, '01-05-2022', 2);
insert into NOTA values (1575, 'activitate independenta', 96342, 11, '29-02-2022', 8);
insert into NOTA values (1200, 'teza', 65744, 13, '15-03-2022', 3);
insert into NOTA values (121, 'evaluare finala', 18985, 7, '20-12-2022', 4);
insert into NOTA values (291, 'teza', 56729, 11, '24-01-2022', 9);
insert into NOTA values (402, 'evaluare', 59829, 18, '15-05-2022', 8);
insert into NOTA values (1887, 'activitate independenta', 34008, 9, '21-06-2022', 4);
insert into NOTA values (569, 'examen', 91566, 1, '14-10-2022', 3);
insert into NOTA values (645, 'test', 59985, 15, '02-03-2022', 6);
insert into NOTA values (1280, 'examen', 39499, 8, '28-02-2022', 1);
insert into NOTA values (1018, 'test', 78878, 14, '24-09-2022', 7);
insert into NOTA values (325, 'test', 26503, 8, '11-02-2022', 10);
insert into NOTA values (1936, 'evaluare', 41915, 1, '13-12-2022', 6);
insert into NOTA values (854, 'evaluare finala', 95857, 5, '04-10-2022', 7);
insert into NOTA values (1003, 'test', 51581, 3, '06-10-2022', 6);
insert into NOTA values (1271, 'evaluare', 42853, 13, '01-06-2022', 1);
insert into NOTA values (1067, 'test', 59321, 18, '12-03-2022', 7);
insert into NOTA values (108, 'evaluare', 59573, 6, '16-08-2022', 3);
insert into NOTA values (1747, 'test', 80663, 6, '02-08-2022', 1);
insert into NOTA values (1796, 'teza', 58540, 16, '27-10-2022', 3);
insert into NOTA values (1240, 'examen', 37671, 16, '29-07-2022', 7);
insert into NOTA values (1514, 'teza', 32932, 2, '29-08-2022', 6);
insert into NOTA values (124, 'teza', 23630, 2, '12-04-2022', 5);
insert into NOTA values (1697, 'examen', 18177, 7, '13-07-2022', 9);
insert into NOTA values (384, 'evaluare', 18177, 20, '12-06-2022', 6);
insert into NOTA values (752, 'activitate independenta', 79308, 15, '15-07-2022', 3);
insert into NOTA values (632, 'test', 68054, 7, '10-06-2022', 8);
insert into NOTA values (888, 'evaluare', 79766, 7, '24-01-2022', 3);
insert into NOTA values (1923, 'evaluare', 95857, 18, '26-08-2022', 8);
insert into NOTA values (941, 'test', 79107, 20, '23-04-2022', 2);
insert into NOTA values (561, 'activitate independenta', 25275, 17, '20-10-2022', 5);
insert into NOTA values (273, 'evaluare finala', 59054, 20, '01-09-2022', 10);
insert into NOTA values (1644, 'teza', 97049, 8, '13-10-2022', 4);
insert into NOTA values (810, 'evaluare finala', 65045, 17, '15-02-2022', 9);
insert into NOTA values (663, 'teza', 39499, 1, '03-06-2022', 10);
insert into NOTA values (518, 'teza', 41056, 17, '11-08-2022', 5);
insert into NOTA values (1328, 'teza', 20134, 16, '23-04-2022', 9);
insert into NOTA values (1072, 'evaluare finala', 26599, 10, '06-09-2022', 8);
insert into NOTA values (459, 'teza', 68054, 2, '03-04-2022', 8);
insert into NOTA values (1625, 'examen', 23630, 14, '18-05-2022', 7);
insert into NOTA values (602, 'evaluare finala', 95640, 14, '25-12-2022', 4);
insert into NOTA values (947, 'evaluare', 45754, 14, '19-06-2022', 5);
insert into NOTA values (857, 'examen', 71224, 5, '03-02-2022', 8);
insert into NOTA values (992, 'evaluare finala', 35731, 9, '12-09-2022', 4);
insert into NOTA values (649, 'test', 31898, 7, '19-05-2022', 3);
insert into NOTA values (446, 'teza', 95640, 6, '01-11-2022', 2);
insert into NOTA values (1309, 'test', 59985, 7, '04-09-2022', 3);
insert into NOTA values (834, 'evaluare', 27911, 4, '17-12-2022', 2);
insert into NOTA values (1832, 'test', 81354, 16, '24-06-2022', 5);
insert into NOTA values (748, 'test', 23455, 1, '06-06-2022', 2);
insert into NOTA values (451, 'examen', 79243, 1, '20-01-2022', 6);
insert into NOTA values (1461, 'teza', 82246, 14, '12-10-2022', 7);
insert into NOTA values (307, 'examen', 76959, 1, '25-03-2022', 8);
insert into NOTA values (1364, 'teza', 23630, 15, '27-09-2022', 7);
insert into NOTA values (1733, 'test', 13200, 3, '08-04-2022', 3);
insert into NOTA values (1609, 'teza', 33799, 13, '05-12-2022', 4);
insert into NOTA values (1912, 'evaluare', 30549, 15, '17-02-2022', 1);
insert into NOTA values (1848, 'activitate independenta', 77928, 7, '12-06-2022', 8);
insert into NOTA values (524, 'test', 95309, 19, '19-03-2022', 5);
insert into NOTA values (591, 'evaluare', 23455, 19, '12-09-2022', 9);
insert into NOTA values (1700, 'teza', 24529, 7, '25-01-2022', 7);
insert into NOTA values (1015, 'evaluare', 71886, 17, '06-12-2022', 10);
insert into NOTA values (1432, 'activitate independenta', 23455, 5, '08-12-2022', 2);
insert into NOTA values (555, 'evaluare finala', 37250, 7, '14-01-2022', 4);
insert into NOTA values (788, 'activitate independenta', 60725, 20, '10-08-2022', 8);
insert into NOTA values (926, 'evaluare', 68054, 12, '01-08-2022', 3);
insert into NOTA values (1163, 'teza', 50210, 18, '10-12-2022', 9);
insert into NOTA values (608, 'evaluare', 79766, 6, '13-01-2022', 6);
insert into NOTA values (222, 'teza', 30736, 9, '01-03-2022', 2);
insert into NOTA values (181, 'teza', 56729, 6, '20-12-2022', 2);
insert into NOTA values (583, 'evaluare', 68716, 2, '11-07-2022', 10);
insert into NOTA values (963, 'teza', 26599, 9, '23-06-2022', 4);
insert into NOTA values (1690, 'teza', 69300, 15, '16-01-2022', 7);
insert into NOTA values (235, 'evaluare finala', 69298, 14, '02-06-2022', 2);
insert into NOTA values (1395, 'examen', 26989, 11, '27-05-2022', 6);
insert into NOTA values (1116, 'evaluare', 49878, 18, '02-09-2022', 2);
insert into NOTA values (1213, 'activitate independenta', 81244, 18, '12-10-2022', 4);
insert into NOTA values (1073, 'evaluare', 44638, 3, '18-06-2022', 4);
insert into NOTA values (1286, 'activitate independenta', 51581, 14, '02-05-2022', 3);
insert into NOTA values (1064, 'evaluare finala', 11702, 10, '08-07-2022', 6);
insert into NOTA values (794, 'examen', 84498, 8, '15-04-2022', 7);
insert into NOTA values (1937, 'examen', 64514, 1, '28-05-2022', 9);
insert into NOTA values (878, 'test', 33799, 20, '20-02-2022', 4);
insert into NOTA values (440, 'activitate independenta', 23455, 10, '01-04-2022', 3);
insert into NOTA values (1027, 'evaluare', 11400, 2, '13-04-2022', 10);
insert into NOTA values (316, 'activitate independenta', 59321, 20, '29-01-2022', 4);
insert into NOTA values (624, 'evaluare finala', 44366, 11, '25-09-2022', 8);
insert into NOTA values (1564, 'teza', 81354, 10, '12-08-2022', 3);
insert into NOTA values (622, 'evaluare', 92384, 16, '10-06-2022', 10);
insert into NOTA values (1062, 'evaluare', 27827, 14, '13-03-2022', 8);
insert into NOTA values (1919, 'teza', 11400, 19, '23-05-2022', 4);
insert into NOTA values (305, 'test', 17661, 1, '19-09-2022', 6);
insert into NOTA values (262, 'teza', 52379, 17, '03-09-2022', 2);
insert into NOTA values (970, 'evaluare finala', 96342, 18, '01-06-2022', 7);
insert into NOTA values (594, 'examen', 42853, 4, '15-01-2022', 6);
insert into NOTA values (960, 'evaluare finala', 11702, 10, '18-04-2022', 1);
insert into NOTA values (1137, 'examen', 76959, 8, '25-01-2022', 10);
insert into NOTA values (1729, 'teza', 17661, 15, '28-01-2022', 9);
insert into NOTA values (1334, 'evaluare', 14991, 13, '27-07-2022', 8);
insert into NOTA values (863, 'test', 51581, 3, '22-10-2022', 1);
insert into NOTA values (126, 'teza', 59573, 18, '07-07-2022', 4);
insert into NOTA values (129, 'examen', 76700, 18, '01-11-2022', 2);
insert into NOTA values (408, 'teza', 79989, 14, '21-04-2022', 5);
insert into NOTA values (1513, 'teza', 91463, 15, '26-01-2022', 5);
insert into NOTA values (1276, 'activitate independenta', 97049, 11, '02-06-2022', 10);
insert into NOTA values (1485, 'evaluare', 30736, 10, '01-09-2022', 3);
insert into NOTA values (937, 'test', 41915, 17, '16-11-2022', 10);
insert into NOTA values (1500, 'teza', 24496, 9, '24-10-2022', 6);
insert into NOTA values (1627, 'evaluare finala', 74535, 14, '01-02-2022', 5);
insert into NOTA values (1602, 'evaluare finala', 44638, 8, '13-05-2022', 5);
insert into NOTA values (256, 'test', 84475, 14, '09-10-2022', 3);
insert into NOTA values (626, 'examen', 97724, 10, '16-01-2022', 9);
insert into NOTA values (337, 'examen', 97049, 11, '12-06-2022', 9);
insert into NOTA values (1850, 'evaluare', 32129, 19, '24-07-2022', 5);
insert into NOTA values (952, 'evaluare finala', 51056, 5, '02-09-2022', 1);
insert into NOTA values (1577, 'evaluare', 84475, 16, '25-05-2022', 10);
insert into NOTA values (1953, 'examen', 78878, 7, '19-07-2022', 9);
insert into NOTA values (488, 'teza', 96162, 11, '05-07-2022', 1);
insert into NOTA values (897, 'activitate independenta', 12019, 11, '11-01-2022', 6);
insert into NOTA values (1610, 'evaluare finala', 13931, 1, '17-09-2022', 9);
insert into NOTA values (684, 'evaluare', 17661, 16, '20-06-2022', 9);
insert into NOTA values (657, 'evaluare finala', 73805, 15, '26-07-2022', 7);
insert into NOTA values (1607, 'activitate independenta', 18177, 6, '15-02-2022', 8);
insert into NOTA values (832, 'teza', 34008, 10, '09-02-2022', 1);
insert into NOTA values (774, 'activitate independenta', 19852, 15, '09-03-2022', 4);
insert into NOTA values (1930, 'test', 11400, 14, '14-05-2022', 3);
insert into NOTA values (617, 'activitate independenta', 78084, 4, '01-05-2022', 3);
insert into NOTA values (1191, 'activitate independenta', 86053, 16, '08-03-2022', 2);
insert into NOTA values (1875, 'examen', 32932, 2, '17-02-2022', 7);
insert into NOTA values (654, 'examen', 51581, 5, '10-06-2022', 2);
insert into NOTA values (1398, 'teza', 99911, 17, '07-04-2022', 4);
insert into NOTA values (538, 'examen', 26503, 8, '26-09-2022', 8);
insert into NOTA values (1894, 'activitate independenta', 24496, 7, '01-07-2022', 8);
insert into NOTA values (1839, 'evaluare finala', 24496, 13, '08-11-2022', 1);
insert into NOTA values (1359, 'activitate independenta', 34008, 10, '10-05-2022', 3);
insert into NOTA values (1975, 'activitate independenta', 32131, 1, '14-07-2022', 2);
insert into NOTA values (369, 'evaluare finala', 56729, 14, '28-10-2022', 1);
insert into NOTA values (461, 'test', 27827, 9, '01-01-2022', 9);
insert into NOTA values (1674, 'evaluare', 79766, 4, '28-03-2022', 1);
insert into NOTA values (817, 'evaluare', 46399, 16, '10-04-2022', 9);
insert into NOTA values (39, 'test', 76297, 19, '19-12-2022', 1);
insert into NOTA values (728, 'test', 25275, 20, '20-09-2022', 2);
insert into NOTA values (915, 'test', 76959, 13, '29-10-2022', 5);
insert into NOTA values (913, 'activitate independenta', 65478, 16, '21-11-2022', 10);
insert into NOTA values (975, 'evaluare finala', 60798, 5, '12-03-2022', 1);
insert into NOTA values (125, 'examen', 91463, 11, '07-10-2022', 8);
insert into NOTA values (1698, 'evaluare', 36123, 16, '05-07-2022', 3);
insert into NOTA values (372, 'evaluare', 19274, 7, '16-06-2022', 4);
insert into NOTA values (983, 'activitate independenta', 17661, 19, '24-09-2022', 1);
insert into NOTA values (979, 'test', 34008, 1, '05-06-2022', 7);
insert into NOTA values (1665, 'test', 44366, 2, '29-03-2022', 8);
insert into NOTA values (1051, 'evaluare finala', 93748, 8, '15-04-2022', 3);
insert into NOTA values (1438, 'test', 95640, 15, '14-11-2022', 1);
insert into NOTA values (935, 'evaluare finala', 37725, 15, '04-08-2022', 1);
insert into NOTA values (919, 'test', 80557, 1, '21-11-2022', 2);
insert into NOTA values (429, 'evaluare finala', 90430, 4, '29-04-2022', 8);
insert into NOTA values (1902, 'teza', 53388, 4, '08-11-2022', 9);
insert into NOTA values (1692, 'examen', 95309, 3, '21-10-2022', 7);
insert into NOTA values (1585, 'test', 49349, 9, '18-02-2022', 5);
insert into NOTA values (1050, 'examen', 35731, 14, '16-11-2022', 8);
insert into NOTA values (289, 'evaluare finala', 34763, 1, '01-12-2022', 8);
insert into NOTA values (786, 'examen', 85447, 6, '16-09-2022', 4);
insert into NOTA values (269, 'evaluare finala', 95640, 15, '29-05-2022', 2);
insert into NOTA values (629, 'activitate independenta', 32932, 14, '25-01-2022', 4);
insert into NOTA values (392, 'test', 87892, 15, '01-12-2022', 7);
insert into NOTA values (668, 'examen', 50327, 10, '24-01-2022', 10);
insert into NOTA values (614, 'evaluare finala', 49349, 8, '06-11-2022', 1);
insert into NOTA values (1384, 'evaluare', 36123, 8, '01-06-2022', 10);
insert into NOTA values (980, 'evaluare finala', 41056, 2, '05-11-2022', 1);
insert into NOTA values (1341, 'activitate independenta', 36123, 18, '25-01-2022', 3);
insert into NOTA values (1969, 'evaluare finala', 84475, 10, '18-05-2022', 9);
insert into NOTA values (1578, 'evaluare', 79243, 1, '21-02-2022', 9);
insert into NOTA values (998, 'test', 95857, 11, '01-10-2022', 4);
insert into NOTA values (590, 'test', 79989, 9, '08-12-2022', 6);
insert into NOTA values (1118, 'evaluare finala', 61371, 5, '01-01-2022', 2);
insert into NOTA values (981, 'evaluare finala', 49858, 8, '11-10-2022', 8);
insert into NOTA values (1263, 'evaluare finala', 60798, 6, '19-11-2022', 9);
insert into NOTA values (962, 'teza', 33799, 10, '06-10-2022', 1);
insert into NOTA values (1057, 'evaluare', 96996, 11, '01-11-2022', 4);
insert into NOTA values (562, 'evaluare finala', 41542, 19, '13-03-2022', 4);
insert into NOTA values (948, 'activitate independenta', 11702, 9, '02-02-2022', 2);
insert into NOTA values (1413, 'evaluare', 41915, 4, '18-08-2022', 4);
insert into NOTA values (1154, 'evaluare finala', 56729, 15, '20-12-2022', 9);
insert into NOTA values (1314, 'test', 30730, 16, '19-06-2022', 9);
insert into NOTA values (333, 'activitate independenta', 26503, 15, '08-09-2022', 2);
insert into NOTA values (1679, 'examen', 80663, 17, '14-09-2022', 6);
insert into NOTA values (896, 'teza', 77928, 3, '24-09-2022', 2);
insert into NOTA values (852, 'teza', 70793, 8, '16-03-2022', 5);
insert into NOTA values (38, 'teza', 71224, 5, '23-11-2022', 3);
insert into NOTA values (1031, 'activitate independenta', 85447, 15, '24-09-2022', 1);
insert into NOTA values (1635, 'examen', 90430, 7, '06-02-2022', 9);
insert into NOTA values (1440, 'teza', 61371, 12, '12-01-2022', 9);
insert into NOTA values (477, 'teza', 17661, 9, '25-08-2022', 8);
insert into NOTA values (1158, 'test', 79308, 2, '16-10-2022', 2);
insert into NOTA values (1393, 'examen', 64514, 1, '05-02-2022', 1);
insert into NOTA values (724, 'evaluare', 76700, 7, '20-11-2022', 1);
insert into NOTA values (438, 'teza', 61371, 1, '28-03-2022', 8);
insert into NOTA values (1168, 'activitate independenta', 49878, 20, '27-02-2022', 3);
insert into NOTA values (1621, 'evaluare', 33279, 9, '10-01-2022', 6);
insert into NOTA values (463, 'activitate independenta', 61371, 16, '10-10-2022', 2);
insert into NOTA values (1292, 'evaluare finala', 85447, 8, '01-11-2022', 1);
insert into NOTA values (455, 'teza', 41056, 13, '15-09-2022', 5);
insert into NOTA values (554, 'activitate independenta', 42980, 16, '14-03-2022', 5);
insert into NOTA values (1145, 'evaluare finala', 58540, 3, '06-08-2022', 7);
insert into NOTA values (1805, 'evaluare', 59985, 5, '09-08-2022', 3);
insert into NOTA values (1189, 'test', 96162, 6, '25-09-2022', 10);
insert into NOTA values (1119, 'activitate independenta', 96342, 20, '19-06-2022', 1);
insert into NOTA values (660, 'teza', 96342, 1, '18-08-2022', 10);
insert into NOTA values (1117, 'evaluare', 86601, 15, '01-11-2022', 7);
insert into NOTA values (861, 'examen', 54270, 2, '08-07-2022', 4);
insert into NOTA values (1171, 'evaluare finala', 41813, 3, '01-02-2022', 9);
insert into NOTA values (621, 'evaluare finala', 23455, 7, '22-12-2022', 4);
insert into NOTA values (1308, 'test', 26599, 2, '25-12-2022', 1);
insert into NOTA values (1668, 'test', 48418, 13, '27-01-2022', 10);
insert into NOTA values (1144, 'evaluare finala', 34763, 8, '10-09-2022', 6);
insert into NOTA values (658, 'teza', 10575, 5, '26-04-2022', 3);
insert into NOTA values (816, 'examen', 68069, 14, '14-06-2022', 3);
insert into NOTA values (1315, 'test', 86053, 14, '01-09-2022', 4);
insert into NOTA values (777, 'teza', 13170, 13, '24-03-2022', 1);
insert into NOTA values (1426, 'evaluare finala', 31898, 17, '23-03-2022', 4);
insert into NOTA values (365, 'activitate independenta', 65045, 8, '09-09-2022', 2);
insert into NOTA values (82, 'evaluare finala', 81354, 19, '14-06-2022', 4);
insert into NOTA values (879, 'activitate independenta', 42853, 9, '09-11-2022', 9);
insert into NOTA values (1757, 'activitate independenta', 34961, 12, '24-11-2022', 4);
insert into NOTA values (1281, 'activitate independenta', 30730, 7, '16-09-2022', 3);
insert into NOTA values (1966, 'test', 17661, 17, '19-04-2022', 9);
insert into NOTA values (1541, 'teza', 52047, 20, '23-07-2022', 8);
insert into NOTA values (1907, 'teza', 13931, 20, '29-12-2022', 10);
insert into NOTA values (598, 'evaluare', 70839, 11, '18-06-2022', 9);
insert into NOTA values (1974, 'test', 69300, 3, '11-09-2022', 7);
insert into NOTA values (1526, 'evaluare finala', 37725, 12, '22-05-2022', 10);
insert into NOTA values (1986, 'evaluare finala', 19274, 17, '29-06-2022', 10);
insert into NOTA values (221, 'evaluare finala', 46399, 10, '16-11-2022', 10);
insert into NOTA values (182, 'examen', 32129, 17, '10-12-2022', 3);
insert into NOTA values (737, 'evaluare', 78878, 19, '20-10-2022', 7);
insert into NOTA values (1591, 'teza', 49878, 14, '12-03-2022', 2);
insert into NOTA values (1598, 'examen', 93748, 7, '28-01-2022', 1);
insert into NOTA values (1074, 'examen', 65045, 16, '20-02-2022', 3);
insert into NOTA values (1768, 'test', 58540, 18, '01-10-2022', 6);
insert into NOTA values (616, 'teza', 97049, 6, '21-09-2022', 8);
insert into NOTA values (60, 'evaluare', 41542, 15, '11-04-2022', 2);
insert into NOTA values (482, 'evaluare', 59825, 6, '01-12-2022', 1);
insert into NOTA values (11, 'activitate independenta', 52700, 16, '20-06-2022', 1);
insert into NOTA values (47, 'evaluare finala', 96162, 12, '07-11-2022', 9);
insert into NOTA values (1345, 'examen', 41915, 11, '18-02-2022', 6);
insert into NOTA values (25, 'teza', 71447, 10, '26-08-2022', 10);
insert into NOTA values (1851, 'test', 47168, 12, '10-09-2022', 3);
insert into NOTA values (1246, 'evaluare', 59755, 20, '13-08-2022', 3);
insert into NOTA values (1574, 'teza', 66790, 2, '07-10-2022', 3);
insert into NOTA values (1822, 'examen', 82246, 8, '14-08-2022', 10);
insert into NOTA values (44, 'examen', 26503, 7, '07-10-2022', 2);
insert into NOTA values (399, 'activitate independenta', 46399, 1, '02-10-2022', 8);
insert into NOTA values (950, 'test', 59825, 12, '03-04-2022', 3);
insert into NOTA values (1293, 'evaluare', 13170, 11, '17-05-2022', 5);
insert into NOTA values (712, 'teza', 71224, 3, '20-10-2022', 7);
insert into NOTA values (656, 'activitate independenta', 15269, 15, '15-12-2022', 1);
insert into NOTA values (778, 'teza', 27911, 7, '21-07-2022', 6);
insert into NOTA values (1855, 'evaluare finala', 48418, 9, '22-02-2022', 3);
insert into NOTA values (991, 'test', 33279, 5, '29-07-2022', 9);
insert into NOTA values (1002, 'activitate independenta', 18177, 19, '01-09-2022', 3);
insert into NOTA values (1827, 'examen', 81244, 8, '10-06-2022', 2);
insert into NOTA values (158, 'evaluare finala', 84873, 14, '09-08-2022', 3);
insert into NOTA values (146, 'evaluare', 32887, 2, '26-05-2022', 9);
insert into NOTA values (702, 'evaluare finala', 13200, 7, '10-07-2022', 10);
insert into NOTA values (579, 'evaluare', 68054, 5, '17-04-2022', 3);
insert into NOTA values (1559, 'examen', 30497, 13, '26-04-2022', 1);
insert into NOTA values (1844, 'activitate independenta', 82246, 7, '26-12-2022', 2);
insert into NOTA values (382, 'teza', 13931, 5, '19-12-2022', 5);
insert into NOTA values (255, 'teza', 59321, 19, '01-02-2022', 4);
insert into NOTA values (1360, 'evaluare', 68054, 12, '06-04-2022', 10);
insert into NOTA values (1084, 'evaluare', 71447, 2, '03-01-2022', 1);
insert into NOTA values (1987, 'test', 13170, 1, '20-07-2022', 6);
insert into NOTA values (1479, 'evaluare finala', 69298, 5, '12-02-2022', 8);
insert into NOTA values (1878, 'teza', 27022, 9, '17-04-2022', 6);
insert into NOTA values (946, 'activitate independenta', 58540, 7, '22-05-2022', 3);
insert into NOTA values (418, 'activitate independenta', 71224, 4, '05-06-2022', 2);
insert into NOTA values (1160, 'activitate independenta', 32129, 3, '20-08-2022', 5);
insert into NOTA values (377, 'evaluare', 18177, 3, '12-04-2022', 5);
insert into NOTA values (1846, 'test', 68069, 5, '21-08-2022', 8);
insert into NOTA values (1487, 'examen', 27827, 11, '08-07-2022', 10);
insert into NOTA values (1489, 'evaluare', 79766, 6, '28-04-2022', 9);
insert into NOTA values (1238, 'examen', 46399, 2, '04-03-2022', 4);
insert into NOTA values (855, 'teza', 76297, 5, '07-03-2022', 8);
insert into NOTA values (757, 'evaluare finala', 79308, 14, '18-02-2022', 4);
insert into NOTA values (427, 'test', 81003, 2, '23-03-2022', 2);
insert into NOTA values (1379, 'activitate independenta', 95188, 12, '10-08-2022', 3);
insert into NOTA values (759, 'examen', 84873, 9, '23-11-2022', 1);
insert into NOTA values (1441, 'evaluare', 77928, 2, '13-12-2022', 1);
insert into NOTA values (1935, 'evaluare', 53388, 1, '20-10-2022', 1);
insert into NOTA values (727, 'evaluare', 52700, 6, '03-11-2022', 8);
insert into NOTA values (433, 'examen', 80557, 13, '05-08-2022', 4);
insert into NOTA values (245, 'teza', 51056, 8, '25-11-2022', 5);
insert into NOTA values (168, 'test', 20449, 15, '02-06-2022', 5);
insert into NOTA values (1110, 'activitate independenta', 80557, 3, '23-11-2022', 1);
insert into NOTA values (1053, 'evaluare', 46821, 16, '20-04-2022', 4);
insert into NOTA values (522, 'evaluare', 73805, 19, '09-03-2022', 4);
insert into NOTA values (1049, 'activitate independenta', 97706, 17, '27-04-2022', 10);
insert into NOTA values (338, 'activitate independenta', 69929, 10, '06-11-2022', 6);
insert into NOTA values (544, 'teza', 71170, 13, '23-09-2022', 2);
insert into NOTA values (1172, 'teza', 30730, 16, '08-06-2022', 2);
insert into NOTA values (1917, 'examen', 37725, 15, '15-07-2022', 6);
insert into NOTA values (743, 'test', 12276, 7, '29-06-2022', 6);
insert into NOTA values (1507, 'activitate independenta', 13200, 1, '01-02-2022', 5);
insert into NOTA values (310, 'examen', 32887, 4, '08-03-2022', 10);
insert into NOTA values (215, 'examen', 66790, 5, '01-08-2022', 9);
insert into NOTA values (1148, 'test', 53992, 2, '06-11-2022', 10);
insert into NOTA values (330, 'test', 12930, 8, '01-03-2022', 9);
insert into NOTA values (120, 'teza', 17661, 5, '16-03-2022', 5);
insert into NOTA values (1444, 'examen', 97049, 20, '01-01-2022', 3);
insert into NOTA values (1409, 'teza', 41056, 13, '25-11-2022', 6);
insert into NOTA values (447, 'teza', 25275, 4, '05-01-2022', 1);
insert into NOTA values (1272, 'examen', 81244, 19, '03-11-2022', 7);
insert into NOTA values (1593, 'teza', 32932, 2, '08-09-2022', 10);
insert into NOTA values (16, 'teza', 97724, 14, '21-10-2022', 5);
insert into NOTA values (1642, 'evaluare', 87780, 18, '08-02-2022', 6);
insert into NOTA values (496, 'activitate independenta', 84873, 2, '17-01-2022', 2);
insert into NOTA values (443, 'examen', 79308, 5, '26-04-2022', 3);
insert into NOTA values (1811, 'evaluare finala', 95640, 18, '26-10-2022', 2);
insert into NOTA values (1835, 'test', 50210, 4, '09-02-2022', 1);
insert into NOTA values (240, 'activitate independenta', 50327, 1, '14-12-2022', 6);
insert into NOTA values (87, 'evaluare finala', 93378, 12, '22-03-2022', 10);
insert into NOTA values (296, 'activitate independenta', 42853, 6, '23-06-2022', 3);
insert into NOTA values (70, 'teza', 25275, 17, '03-12-2022', 8);
insert into NOTA values (1961, 'evaluare finala', 79308, 6, '13-12-2022', 7);
insert into NOTA values (868, 'test', 59755, 5, '21-04-2022', 2);
insert into NOTA values (686, 'teza', 68054, 13, '05-09-2022', 6);
insert into NOTA values (550, 'teza', 32651, 8, '29-09-2022', 6);
insert into NOTA values (1558, 'evaluare finala', 81244, 9, '04-05-2022', 10);
insert into NOTA values (512, 'evaluare finala', 77632, 12, '01-01-2022', 1);
insert into NOTA values (8, 'examen', 36123, 8, '28-12-2022', 1);
insert into NOTA values (1788, 'test', 50210, 16, '22-01-2022', 1);
insert into NOTA values (1546, 'evaluare', 48303, 8, '25-10-2022', 4);
insert into NOTA values (927, 'evaluare finala', 52700, 19, '24-10-2022', 4);
insert into NOTA values (603, 'activitate independenta', 86557, 19, '16-09-2022', 2);
insert into NOTA values (93, 'test', 93748, 10, '07-05-2022', 3);
insert into NOTA values (456, 'evaluare', 69300, 6, '06-01-2022', 8);
insert into NOTA values (292, 'teza', 50327, 4, '01-04-2022', 2);
insert into NOTA values (934, 'evaluare', 93071, 16, '22-07-2022', 10);
insert into NOTA values (344, 'evaluare', 80663, 2, '24-01-2022', 10);
insert into NOTA values (1331, 'examen', 35283, 5, '11-12-2022', 8);
insert into NOTA values (1056, 'teza', 58914, 7, '29-10-2022', 5);
insert into NOTA values (1033, 'test', 85447, 14, '02-12-2022', 8);
insert into NOTA values (469, 'evaluare', 93071, 5, '04-08-2022', 2);
insert into NOTA values (669, 'examen', 36123, 19, '07-10-2022', 9);
insert into NOTA values (470, 'examen', 71170, 12, '01-02-2022', 6);
insert into NOTA values (1550, 'test', 23455, 2, '16-04-2022', 2);
insert into NOTA values (818, 'evaluare', 12930, 9, '21-07-2022', 9);
insert into NOTA values (780, 'activitate independenta', 60798, 8, '04-08-2022', 5);
insert into NOTA values (394, 'examen', 59755, 14, '20-04-2022', 1);
insert into NOTA values (17, 'activitate independenta', 27911, 2, '27-10-2022', 7);
insert into NOTA values (1623, 'activitate independenta', 80557, 16, '05-05-2022', 10);
insert into NOTA values (820, 'teza', 27022, 3, '07-11-2022', 9);
insert into NOTA values (1572, 'test', 58540, 9, '25-01-2022', 6);
insert into NOTA values (736, 'evaluare', 49349, 7, '03-02-2022', 4);
insert into NOTA values (1232, 'activitate independenta', 80663, 2, '03-08-2022', 10);
insert into NOTA values (1818, 'examen', 60798, 12, '10-10-2022', 3);
insert into NOTA values (1608, 'evaluare finala', 37671, 1, '01-09-2022', 6);
insert into NOTA values (114, 'test', 84873, 6, '19-12-2022', 10);
insert into NOTA values (1408, 'evaluare finala', 41915, 8, '10-05-2022', 5);
insert into NOTA values (1089, 'examen', 11594, 13, '01-05-2022', 6);
insert into NOTA values (1840, 'examen', 79107, 13, '02-04-2022', 4);
insert into NOTA values (1713, 'teza', 30549, 7, '16-04-2022', 5);
insert into NOTA values (1899, 'examen', 18177, 1, '29-07-2022', 4);
insert into NOTA values (1694, 'teza', 42853, 7, '24-06-2022', 4);
insert into NOTA values (746, 'test', 23455, 12, '07-10-2022', 1);
insert into NOTA values (1996, 'test', 70793, 10, '01-02-2022', 5);
insert into NOTA values (1676, 'activitate independenta', 51581, 13, '04-03-2022', 5);
insert into NOTA values (154, 'activitate independenta', 39639, 1, '29-07-2022', 5);
insert into NOTA values (1497, 'evaluare finala', 19852, 3, '13-02-2022', 7);
insert into NOTA values (1856, 'examen', 19852, 9, '04-08-2022', 4);
insert into NOTA values (1512, 'teza', 33279, 1, '21-07-2022', 7);
insert into NOTA values (360, 'examen', 46821, 1, '20-08-2022', 5);
insert into NOTA values (1437, 'evaluare finala', 17661, 13, '23-12-2022', 1);
insert into NOTA values (796, 'evaluare', 59321, 9, '13-10-2022', 8);
insert into NOTA values (967, 'teza', 26989, 8, '23-02-2022', 10);
insert into NOTA values (1562, 'examen', 79107, 3, '02-04-2022', 9);
insert into NOTA values (1011, 'teza', 56729, 16, '14-10-2022', 7);
insert into NOTA values (1494, 'teza', 79107, 16, '17-06-2022', 5);
insert into NOTA values (730, 'teza', 84475, 11, '16-03-2022', 4);
insert into NOTA values (1287, 'test', 78084, 6, '04-09-2022', 9);
insert into NOTA values (1249, 'evaluare', 23630, 12, '22-02-2022', 6);
insert into NOTA values (1282, 'teza', 37725, 19, '01-11-2022', 5);
insert into NOTA values (35, 'evaluare finala', 65478, 3, '12-01-2022', 9);
insert into NOTA values (503, 'teza', 23630, 11, '12-09-2022', 9);
insert into NOTA values (51, 'evaluare finala', 65478, 19, '01-01-2022', 2);
insert into NOTA values (1563, 'evaluare finala', 12930, 16, '01-05-2022', 10);
insert into NOTA values (1736, 'evaluare finala', 69929, 8, '02-09-2022', 10);
insert into NOTA values (141, 'teza', 41915, 11, '06-03-2022', 7);
insert into NOTA values (695, 'examen', 79243, 19, '05-02-2022', 2);
insert into NOTA values (840, 'evaluare', 44638, 19, '17-12-2022', 10);
insert into NOTA values (1019, 'test', 50210, 9, '13-09-2022', 4);
insert into NOTA values (171, 'teza', 32932, 5, '01-02-2022', 8);
insert into NOTA values (1153, 'evaluare', 80557, 10, '26-11-2022', 5);
insert into NOTA values (1775, 'examen', 91433, 8, '22-12-2022', 10);
insert into NOTA values (91, 'activitate independenta', 14991, 15, '05-10-2022', 9);
insert into NOTA values (1190, 'examen', 60798, 9, '21-09-2022', 6);
insert into NOTA values (1472, 'evaluare finala', 15269, 3, '25-11-2022', 2);
insert into NOTA values (110, 'examen', 37671, 17, '16-06-2022', 3);
insert into NOTA values (787, 'examen', 37156, 2, '21-05-2022', 4);
insert into NOTA values (33, 'activitate independenta', 67084, 18, '14-03-2022', 9);
insert into NOTA values (679, 'examen', 26599, 4, '06-07-2022', 7);
insert into NOTA values (1853, 'examen', 23455, 11, '29-04-2022', 4);
insert into NOTA values (26, 'examen', 85447, 5, '03-06-2022', 1);
insert into NOTA values (478, 'teza', 84475, 19, '20-05-2022', 1);
insert into NOTA values (1239, 'teza', 86557, 17, '14-06-2022', 2);
insert into NOTA values (202, 'teza', 82246, 15, '14-11-2022', 3);
insert into NOTA values (97, 'test', 58540, 6, '10-04-2022', 4);
insert into NOTA values (929, 'test', 67084, 7, '20-05-2022', 1);
insert into NOTA values (584, 'examen', 76297, 4, '17-08-2022', 4);
insert into NOTA values (638, 'evaluare', 71447, 17, '08-05-2022', 9);
insert into NOTA values (1324, 'test', 58540, 10, '21-03-2022', 3);
insert into NOTA values (648, 'test', 18177, 17, '17-08-2022', 8);
insert into NOTA values (845, 'activitate independenta', 41050, 15, '02-09-2022', 5);
insert into NOTA values (415, 'evaluare finala', 24529, 20, '17-07-2022', 1);
insert into NOTA values (185, 'evaluare finala', 44638, 8, '24-07-2022', 9);
insert into NOTA values (136, 'activitate independenta', 32131, 13, '06-06-2022', 9);
insert into NOTA values (639, 'test', 33279, 19, '05-10-2022', 8);
insert into NOTA values (1414, 'evaluare', 25275, 20, '25-06-2022', 1);
insert into NOTA values (689, 'evaluare finala', 81354, 12, '19-10-2022', 3);
insert into NOTA values (1248, 'evaluare', 58914, 4, '06-01-2022', 2);
insert into NOTA values (1709, 'teza', 87892, 15, '12-03-2022', 10);
insert into NOTA values (395, 'evaluare', 26599, 4, '05-05-2022', 4);
insert into NOTA values (1890, 'evaluare', 84873, 7, '24-11-2022', 4);
insert into NOTA values (521, 'evaluare', 79989, 1, '15-10-2022', 5);
insert into NOTA values (865, 'evaluare', 41050, 13, '24-05-2022', 1);
insert into NOTA values (1964, 'examen', 85575, 19, '28-11-2022', 8);
insert into NOTA values (1749, 'evaluare', 93071, 14, '09-05-2022', 6);
insert into NOTA values (236, 'evaluare', 37156, 19, '27-06-2022', 3);
insert into NOTA values (870, 'activitate independenta', 71886, 3, '25-06-2022', 2);
insert into NOTA values (1955, 'test', 93378, 17, '16-02-2022', 8);
insert into NOTA values (1265, 'examen', 68054, 17, '18-08-2022', 4);
insert into NOTA values (956, 'examen', 13931, 12, '07-09-2022', 5);
insert into NOTA values (1405, 'test', 30549, 1, '13-05-2022', 7);
insert into NOTA values (1125, 'examen', 68069, 15, '07-11-2022', 8);
insert into NOTA values (1624, 'activitate independenta', 59755, 8, '25-10-2022', 9);
insert into NOTA values (685, 'examen', 37156, 1, '19-06-2022', 4);
insert into NOTA values (741, 'teza', 11594, 5, '26-07-2022', 6);
insert into NOTA values (250, 'evaluare', 35731, 20, '28-08-2022', 6);
insert into NOTA values (553, 'evaluare', 81003, 11, '09-03-2022', 3);
insert into NOTA values (127, 'test', 20134, 6, '27-05-2022', 8);
insert into NOTA values (1133, 'teza', 81003, 4, '08-06-2022', 2);
insert into NOTA values (1940, 'examen', 50327, 18, '19-11-2022', 1);
insert into NOTA values (288, 'teza', 35283, 5, '05-03-2022', 8);
insert into NOTA values (152, 'examen', 59573, 17, '25-12-2022', 4);
insert into NOTA values (1854, 'evaluare', 93748, 8, '21-04-2022', 3);
insert into NOTA values (1551, 'evaluare', 87780, 2, '17-07-2022', 6);
insert into NOTA values (1880, 'examen', 47168, 5, '03-09-2022', 1);
insert into NOTA values (468, 'examen', 13170, 8, '06-03-2022', 6);
insert into NOTA values (1044, 'test', 76700, 7, '27-12-2022', 1);
insert into NOTA values (495, 'activitate independenta', 58035, 1, '16-04-2022', 10);
insert into NOTA values (1859, 'examen', 68069, 16, '21-10-2022', 9);
insert into NOTA values (824, 'evaluare', 70839, 20, '14-01-2022', 7);
insert into NOTA values (234, 'teza', 99911, 8, '08-06-2022', 8);
insert into NOTA values (1465, 'evaluare', 58540, 14, '05-04-2022', 3);
insert into NOTA values (188, 'examen', 94765, 20, '01-02-2022', 2);
insert into NOTA values (726, 'examen', 27720, 11, '18-07-2022', 1);
insert into NOTA values (1060, 'examen', 36123, 3, '27-02-2022', 2);
insert into NOTA values (1510, 'examen', 59829, 13, '22-07-2022', 7);
insert into NOTA values (1632, 'activitate independenta', 65744, 1, '15-01-2022', 1);
insert into NOTA values (1454, 'test', 37156, 4, '01-08-2022', 5);
insert into NOTA values (1225, 'teza', 10575, 2, '02-04-2022', 9);
insert into NOTA values (1422, 'evaluare', 90430, 1, '23-06-2022', 4);
insert into NOTA values (764, 'activitate independenta', 58035, 4, '29-07-2022', 1);
insert into NOTA values (246, 'teza', 85447, 15, '12-05-2022', 10);
insert into NOTA values (373, 'teza', 46821, 6, '01-07-2022', 3);
insert into NOTA values (1237, 'test', 69298, 2, '11-01-2022', 2);
insert into NOTA values (1652, 'teza', 15269, 10, '06-03-2022', 2);
insert into NOTA values (1618, 'evaluare', 42853, 10, '28-03-2022', 3);
insert into NOTA values (327, 'evaluare finala', 34285, 5, '05-12-2022', 2);
insert into NOTA values (1373, 'evaluare finala', 71170, 18, '29-06-2022', 5);
insert into NOTA values (923, 'test', 87780, 13, '18-08-2022', 4);
insert into NOTA values (955, 'activitate independenta', 82246, 14, '21-06-2022', 1);
insert into NOTA values (511, 'evaluare', 42980, 1, '22-09-2022', 5);
insert into NOTA values (1167, 'examen', 46821, 12, '23-03-2022', 10);
insert into NOTA values (1451, 'evaluare', 81244, 17, '21-10-2022', 2);
insert into NOTA values (944, 'test', 12276, 3, '25-12-2022', 7);
insert into NOTA values (203, 'examen', 50327, 14, '11-01-2022', 9);
insert into NOTA values (1486, 'evaluare', 60798, 9, '11-09-2022', 10);
insert into NOTA values (1185, 'activitate independenta', 49858, 14, '03-09-2022', 6);
insert into NOTA values (275, 'examen', 27720, 11, '15-05-2022', 6);
insert into NOTA values (968, 'evaluare', 71886, 12, '01-09-2022', 9);
insert into NOTA values (1530, 'activitate independenta', 89489, 19, '12-11-2022', 5);
insert into NOTA values (558, 'evaluare finala', 59321, 6, '04-01-2022', 6);
insert into NOTA values (1362, 'evaluare', 71447, 16, '04-02-2022', 5);
insert into NOTA values (1615, 'examen', 89489, 17, '02-08-2022', 5);
insert into NOTA values (1392, 'teza', 96996, 14, '01-03-2022', 8);
insert into NOTA values (681, 'examen', 95188, 20, '15-04-2022', 8);
insert into NOTA values (423, 'evaluare finala', 69300, 18, '01-07-2022', 7);
insert into NOTA values (1250, 'evaluare finala', 32129, 8, '12-12-2022', 6);
insert into NOTA values (1096, 'evaluare', 13170, 16, '04-05-2022', 6);
insert into NOTA values (396, 'evaluare', 37725, 10, '01-11-2022', 2);
insert into NOTA values (974, 'teza', 86053, 8, '19-05-2022', 4);
insert into NOTA values (1312, 'evaluare finala', 41542, 11, '01-12-2022', 4);
insert into NOTA values (1233, 'test', 54270, 20, '25-11-2022', 7);
insert into NOTA values (224, 'examen', 96162, 18, '14-01-2022', 10);
insert into NOTA values (1329, 'test', 18177, 9, '12-11-2022', 2);
insert into NOTA values (1343, 'activitate independenta', 70793, 18, '12-08-2022', 1);
insert into NOTA values (161, 'activitate independenta', 34285, 5, '29-01-2022', 9);
insert into NOTA values (1219, 'test', 52047, 9, '07-10-2022', 1);
insert into NOTA values (505, 'teza', 30549, 7, '11-07-2022', 9);
insert into NOTA values (1337, 'test', 10575, 15, '28-02-2022', 1);
insert into NOTA values (277, 'activitate independenta', 30730, 3, '12-12-2022', 9);
insert into NOTA values (445, 'teza', 77928, 10, '23-12-2022', 8);
insert into NOTA values (1921, 'evaluare', 18136, 15, '08-05-2022', 2);
insert into NOTA values (131, 'teza', 70793, 13, '04-06-2022', 8);
insert into NOTA values (53, 'examen', 77632, 9, '22-05-2022', 9);
insert into NOTA values (491, 'evaluare', 31898, 17, '16-10-2022', 8);
insert into NOTA values (1906, 'teza', 10575, 13, '22-02-2022', 7);
insert into NOTA values (808, 'evaluare', 96996, 9, '20-05-2022', 6);
insert into NOTA values (634, 'activitate independenta', 73805, 3, '18-05-2022', 3);
insert into NOTA values (1916, 'evaluare', 59985, 12, '26-04-2022', 2);
insert into NOTA values (334, 'teza', 42980, 15, '04-05-2022', 5);
insert into NOTA values (572, 'activitate independenta', 65744, 10, '20-11-2022', 2);
insert into NOTA values (1081, 'evaluare finala', 34285, 10, '17-09-2022', 3);
insert into NOTA values (1243, 'evaluare finala', 59054, 7, '04-12-2022', 1);
insert into NOTA values (225, 'examen', 50327, 3, '20-09-2022', 6);
insert into NOTA values (619, 'test', 15269, 20, '23-07-2022', 4);
insert into NOTA values (1816, 'evaluare', 93748, 16, '18-03-2022', 4);
insert into NOTA values (675, 'teza', 53388, 19, '12-06-2022', 9);
insert into NOTA values (434, 'activitate independenta', 68069, 13, '03-08-2022', 6);
insert into NOTA values (612, 'evaluare finala', 11702, 11, '17-12-2022', 9);
insert into NOTA values (883, 'examen', 41542, 4, '14-05-2022', 4);
insert into NOTA values (271, 'teza', 51581, 1, '14-03-2022', 4);
insert into NOTA values (92, 'activitate independenta', 97049, 14, '18-10-2022', 6);
insert into NOTA values (274, 'evaluare', 95640, 5, '08-10-2022', 2);
insert into NOTA values (1946, 'test', 42980, 4, '10-09-2022', 7);
insert into NOTA values (1755, 'examen', 41542, 15, '08-01-2022', 9);
insert into NOTA values (1727, 'evaluare finala', 24529, 4, '22-02-2022', 5);
insert into NOTA values (1385, 'activitate independenta', 41542, 6, '15-02-2022', 10);
insert into NOTA values (1131, 'test', 58035, 2, '24-09-2022', 4);
insert into NOTA values (389, 'activitate independenta', 27022, 20, '28-08-2022', 8);
insert into NOTA values (349, 'activitate independenta', 71886, 3, '24-10-2022', 4);
insert into NOTA values (1965, 'examen', 81244, 14, '10-03-2022', 4);
insert into NOTA values (1803, 'test', 59829, 6, '02-07-2022', 5);
insert into NOTA values (54, 'test', 56729, 12, '29-02-2022', 6);
insert into NOTA values (508, 'examen', 32932, 6, '20-03-2022', 5);
insert into NOTA values (1769, 'evaluare', 92384, 5, '03-12-2022', 4);
insert into NOTA values (180, 'teza', 91566, 19, '15-07-2022', 5);
insert into NOTA values (523, 'examen', 84475, 16, '18-01-2022', 8);
insert into NOTA values (1484, 'teza', 95309, 19, '26-11-2022', 2);
insert into NOTA values (1008, 'teza', 53388, 3, '26-07-2022', 8);
insert into NOTA values (1701, 'evaluare finala', 68716, 3, '01-01-2022', 2);
insert into NOTA values (908, 'teza', 41915, 10, '19-08-2022', 2);
insert into NOTA values (1726, 'teza', 20134, 13, '26-12-2022', 9);
insert into NOTA values (1823, 'test', 12930, 6, '06-10-2022', 6);
insert into NOTA values (1303, 'activitate independenta', 49858, 6, '12-04-2022', 10);
insert into NOTA values (217, 'evaluare', 59321, 6, '28-07-2022', 1);
insert into NOTA values (293, 'activitate independenta', 58035, 4, '26-10-2022', 7);
insert into NOTA values (994, 'teza', 76959, 4, '13-01-2022', 9);
insert into NOTA values (5, 'examen', 93378, 5, '24-03-2022', 9);
insert into NOTA values (34, 'activitate independenta', 18177, 6, '18-10-2022', 9);
insert into NOTA values (1495, 'test', 30497, 16, '04-07-2022', 4);
insert into NOTA values (356, 'teza', 95640, 10, '27-09-2022', 3);
insert into NOTA values (1587, 'activitate independenta', 60798, 6, '01-10-2022', 7);
insert into NOTA values (1285, 'examen', 97724, 12, '10-12-2022', 7);
insert into NOTA values (166, 'evaluare finala', 59573, 3, '24-02-2022', 1);
insert into NOTA values (1284, 'evaluare', 32129, 16, '01-12-2022', 9);
insert into NOTA values (1649, 'test', 49349, 13, '15-11-2022', 7);
insert into NOTA values (1702, 'activitate independenta', 42853, 13, '29-06-2022', 1);
insert into NOTA values (986, 'test', 42853, 6, '01-04-2022', 10);
insert into NOTA values (1807, 'evaluare finala', 97049, 5, '27-10-2022', 6);
insert into NOTA values (1404, 'examen', 69929, 16, '25-01-2022', 10);
insert into NOTA values (1639, 'evaluare finala', 56729, 13, '02-10-2022', 8);
insert into NOTA values (1734, 'teza', 32651, 9, '29-07-2022', 4);
insert into NOTA values (1173, 'activitate independenta', 51581, 1, '22-09-2022', 2);
insert into NOTA values (1756, 'evaluare finala', 71886, 2, '21-05-2022', 7);
insert into NOTA values (1143, 'teza', 78878, 6, '24-03-2022', 1);
insert into NOTA values (281, 'evaluare finala', 68069, 19, '26-02-2022', 2);
insert into NOTA values (964, 'test', 81244, 8, '05-11-2022', 5);
insert into NOTA values (335, 'evaluare finala', 33279, 18, '22-06-2022', 3);
insert into NOTA values (1968, 'evaluare', 67084, 8, '27-08-2022', 8);
insert into NOTA values (800, 'examen', 54270, 7, '27-05-2022', 3);
insert into NOTA values (284, 'evaluare finala', 85575, 12, '20-05-2022', 10);
insert into NOTA values (1083, 'examen', 46821, 13, '28-01-2022', 3);
insert into NOTA values (1524, 'evaluare', 46399, 2, '26-09-2022', 3);
insert into NOTA values (814, 'evaluare finala', 27827, 7, '13-04-2022', 10);
insert into NOTA values (1192, 'examen', 74966, 17, '23-04-2022', 2);
insert into NOTA values (996, 'examen', 93378, 8, '29-01-2022', 10);
insert into NOTA values (1547, 'examen', 30730, 8, '18-10-2022', 3);
insert into NOTA values (573, 'test', 49858, 7, '10-11-2022', 8);
insert into NOTA values (1236, 'teza', 71170, 10, '23-03-2022', 6);
insert into NOTA values (1347, 'teza', 31898, 3, '10-12-2022', 9);
insert into NOTA values (1614, 'evaluare', 76297, 5, '01-01-2022', 6);
insert into NOTA values (71, 'teza', 41813, 4, '01-01-2022', 10);
insert into NOTA values (1741, 'teza', 32131, 6, '02-12-2022', 7);
insert into NOTA values (332, 'evaluare', 82246, 4, '16-10-2022', 7);
insert into NOTA values (1042, 'examen', 95188, 8, '24-05-2022', 1);
insert into NOTA values (286, 'activitate independenta', 96996, 20, '17-09-2022', 7);
insert into NOTA values (381, 'activitate independenta', 54270, 11, '10-10-2022', 5);
insert into NOTA values (308, 'evaluare finala', 96342, 5, '03-02-2022', 6);
insert into NOTA values (1865, 'examen', 93378, 1, '16-06-2022', 1);
insert into NOTA values (341, 'evaluare finala', 68069, 10, '28-08-2022', 3);
insert into NOTA values (1879, 'evaluare finala', 76959, 6, '24-07-2022', 3);
insert into NOTA values (1459, 'examen', 81003, 12, '14-03-2022', 1);
insert into NOTA values (864, 'evaluare', 71886, 4, '15-12-2022', 9);
insert into NOTA values (1631, 'evaluare finala', 48418, 20, '25-10-2022', 7);
insert into NOTA values (380, 'test', 46821, 9, '09-01-2022', 8);
insert into NOTA values (604, 'test', 92504, 12, '24-05-2022', 8);
insert into NOTA values (1646, 'evaluare finala', 91566, 10, '15-12-2022', 1);
insert into NOTA values (1555, 'activitate independenta', 52379, 19, '29-07-2022', 8);
insert into NOTA values (198, 'evaluare finala', 51581, 4, '08-12-2022', 3);
insert into NOTA values (1666, 'test', 41813, 12, '25-05-2022', 7);
insert into NOTA values (1058, 'evaluare', 34285, 20, '07-02-2022', 7);
insert into NOTA values (1417, 'test', 74535, 5, '11-11-2022', 5);
insert into NOTA values (1770, 'teza', 70793, 10, '02-07-2022', 7);
insert into NOTA values (1339, 'evaluare finala', 33799, 12, '15-05-2022', 8);
insert into NOTA values (1999, 'examen', 49349, 3, '13-12-2022', 10);
insert into NOTA values (206, 'test', 69298, 14, '26-02-2022', 6);
insert into NOTA values (1707, 'examen', 35731, 3, '20-11-2022', 8);
insert into NOTA values (1183, 'examen', 92384, 2, '07-10-2022', 2);
insert into NOTA values (1688, 'test', 34008, 13, '25-02-2022', 8);
insert into NOTA values (1630, 'activitate independenta', 17661, 15, '08-11-2022', 10);
insert into NOTA values (220, 'evaluare finala', 15269, 11, '06-03-2022', 7);
insert into NOTA values (551, 'teza', 65744, 3, '29-08-2022', 10);
insert into NOTA values (1629, 'test', 82246, 19, '11-09-2022', 9);
insert into NOTA values (1214, 'evaluare', 27911, 9, '19-11-2022', 4);
insert into NOTA values (1944, 'teza', 26599, 17, '08-06-2022', 10);
insert into NOTA values (1106, 'test', 80663, 9, '23-10-2022', 3);
insert into NOTA values (260, 'teza', 24529, 15, '23-12-2022', 4);
insert into NOTA values (62, 'teza', 69298, 10, '05-02-2022', 9);
insert into NOTA values (24, 'evaluare', 84498, 2, '01-06-2022', 10);
insert into NOTA values (1327, 'teza', 58540, 18, '05-10-2022', 8);
insert into NOTA values (1162, 'evaluare finala', 15687, 4, '13-06-2022', 6);
insert into NOTA values (1224, 'examen', 41050, 18, '13-11-2022', 5);
insert into NOTA values (1178, 'teza', 63531, 8, '06-06-2022', 8);
insert into NOTA values (75, 'examen', 82246, 3, '25-05-2022', 1);
insert into NOTA values (971, 'evaluare finala', 37671, 2, '11-12-2022', 4);
insert into NOTA values (1871, 'test', 27827, 18, '19-08-2022', 8);
insert into NOTA values (1706, 'evaluare finala', 74966, 5, '14-05-2022', 7);
insert into NOTA values (1226, 'evaluare', 59321, 10, '15-07-2022', 8);
insert into NOTA values (89, 'activitate independenta', 48303, 7, '09-04-2022', 7);
insert into NOTA values (563, 'activitate independenta', 86053, 18, '18-05-2022', 10);
insert into NOTA values (1207, 'teza', 41915, 18, '18-05-2022', 1);
insert into NOTA values (1102, 'activitate independenta', 37725, 9, '02-01-2022', 4);
insert into NOTA values (688, 'examen', 12276, 17, '14-09-2022', 2);
insert into NOTA values (1925, 'teza', 34285, 14, '18-10-2022', 6);
insert into NOTA values (306, 'teza', 32129, 20, '08-08-2022', 7);
insert into NOTA values (605, 'activitate independenta', 44638, 8, '25-07-2022', 1);
insert into NOTA values (630, 'test', 82246, 4, '19-04-2022', 4);
insert into NOTA values (1323, 'evaluare finala', 11400, 3, '28-03-2022', 8);
insert into NOTA values (210, 'teza', 78084, 5, '09-02-2022', 5);
insert into NOTA values (1212, 'activitate independenta', 84498, 15, '10-10-2022', 1);
insert into NOTA values (1699, 'examen', 78878, 5, '04-02-2022', 10);
insert into NOTA values (354, 'activitate independenta', 99911, 14, '23-08-2022', 1);
insert into NOTA values (1302, 'evaluare finala', 69298, 3, '06-05-2022', 10);
insert into NOTA values (376, 'test', 44366, 18, '02-08-2022', 8);
insert into NOTA values (101, 'evaluare finala', 26989, 7, '19-09-2022', 9);
insert into NOTA values (315, 'activitate independenta', 59321, 11, '23-03-2022', 1);
insert into NOTA values (211, 'teza', 74966, 19, '27-11-2022', 9);
insert into NOTA values (1399, 'examen', 95309, 14, '01-02-2022', 2);
insert into NOTA values (111, 'evaluare', 59829, 13, '08-01-2022', 9);
insert into NOTA values (1456, 'examen', 12276, 19, '02-03-2022', 7);
insert into NOTA values (1511, 'teza', 32131, 7, '03-11-2022', 3);
insert into NOTA values (1433, 'teza', 34763, 12, '20-02-2022', 9);
insert into NOTA values (531, 'teza', 96342, 20, '23-01-2022', 2);
insert into NOTA values (1799, 'evaluare', 79243, 1, '08-03-2022', 5);
insert into NOTA values (1208, 'evaluare finala', 47168, 10, '09-10-2022', 8);
insert into NOTA values (385, 'examen', 56729, 16, '07-05-2022', 5);
insert into NOTA values (1086, 'evaluare finala', 67084, 5, '28-08-2022', 5);
insert into NOTA values (951, 'examen', 79243, 16, '06-06-2022', 7);
insert into NOTA values (750, 'examen', 70793, 13, '18-05-2022', 3);
insert into NOTA values (353, 'test', 59321, 19, '18-04-2022', 4);
insert into NOTA values (499, 'teza', 24496, 17, '14-09-2022', 6);
insert into NOTA values (978, 'activitate independenta', 79107, 3, '06-11-2022', 10);
insert into NOTA values (1723, 'teza', 37725, 17, '13-04-2022', 3);
insert into NOTA values (1480, 'evaluare', 60725, 9, '08-02-2022', 2);
insert into NOTA values (1633, 'evaluare finala', 95309, 19, '09-05-2022', 2);
insert into NOTA values (747, 'evaluare', 60798, 4, '01-04-2022', 3);
insert into NOTA values (1638, 'teza', 86601, 4, '28-06-2022', 10);
insert into NOTA values (1669, 'teza', 48418, 4, '09-03-2022', 5);
insert into NOTA values (1366, 'activitate independenta', 10575, 2, '21-03-2022', 1);
insert into NOTA values (1222, 'teza', 34763, 4, '19-02-2022', 1);
insert into NOTA values (1275, 'test', 18177, 10, '27-10-2022', 5);
insert into NOTA values (924, 'examen', 41050, 3, '11-05-2022', 3);
insert into NOTA values (282, 'activitate independenta', 70793, 16, '01-03-2022', 10);
insert into NOTA values (1724, 'test', 41056, 9, '03-04-2022', 6);
insert into NOTA values (532, 'test', 76297, 10, '03-02-2022', 1);
insert into NOTA values (1388, 'evaluare finala', 68054, 2, '01-06-2022', 10);
insert into NOTA values (74, 'teza', 49349, 14, '02-09-2022', 1);
insert into NOTA values (331, 'evaluare finala', 71224, 7, '19-05-2022', 7);
insert into NOTA values (1758, 'test', 59054, 10, '01-07-2022', 1);
insert into NOTA values (1886, 'evaluare', 50327, 8, '24-04-2022', 1);
insert into NOTA values (309, 'teza', 81244, 11, '17-03-2022', 6);
insert into NOTA values (1990, 'teza', 15269, 15, '12-01-2022', 4);
insert into NOTA values (515, 'teza', 59054, 15, '08-03-2022', 10);
insert into NOTA values (453, 'evaluare', 68716, 10, '18-11-2022', 9);
insert into NOTA values (1540, 'test', 27720, 13, '01-06-2022', 4);
insert into NOTA values (227, 'examen', 26503, 9, '26-11-2022', 2);
insert into NOTA values (50, 'examen', 34961, 19, '17-10-2022', 2);
insert into NOTA values (790, 'evaluare finala', 91566, 9, '26-03-2022', 10);
insert into NOTA values (1445, 'teza', 86053, 17, '11-02-2022', 2);
insert into NOTA values (419, 'activitate independenta', 96162, 4, '17-12-2022', 10);
insert into NOTA values (1565, 'evaluare', 69300, 15, '24-12-2022', 9);
insert into NOTA values (1198, 'evaluare', 79243, 13, '18-03-2022', 2);
insert into NOTA values (659, 'activitate independenta', 11400, 3, '05-01-2022', 6);
insert into NOTA values (1626, 'examen', 50327, 8, '24-12-2022', 8);
insert into NOTA values (949, 'examen', 86557, 2, '01-03-2022', 7);
insert into NOTA values (1947, 'examen', 59321, 10, '20-01-2022', 8);
insert into NOTA values (1306, 'teza', 59755, 10, '01-12-2022', 1);
insert into NOTA values (1767, 'activitate independenta', 33799, 6, '05-04-2022', 9);
insert into NOTA values (1751, 'evaluare', 32651, 14, '01-04-2022', 10);
insert into NOTA values (1356, 'test', 46821, 11, '17-11-2022', 9);
insert into NOTA values (1950, 'teza', 74535, 6, '17-08-2022', 7);
insert into NOTA values (1431, 'evaluare', 45754, 3, '10-01-2022', 5);
insert into NOTA values (467, 'activitate independenta', 97724, 10, '17-07-2022', 1);
insert into NOTA values (409, 'activitate independenta', 27720, 20, '17-12-2022', 10);
insert into NOTA values (1005, 'evaluare finala', 84498, 13, '01-10-2022', 6);
insert into NOTA values (761, 'evaluare finala', 59755, 3, '20-02-2022', 8);
insert into NOTA values (516, 'test', 80557, 3, '16-02-2022', 2);
insert into NOTA values (1958, 'evaluare finala', 79243, 17, '15-09-2022', 9);
insert into NOTA values (1931, 'teza', 68069, 16, '20-01-2022', 3);
insert into NOTA values (1596, 'test', 59054, 19, '10-07-2022', 5);
insert into NOTA values (1076, 'test', 67084, 1, '04-01-2022', 10);
insert into NOTA values (1297, 'activitate independenta', 37156, 8, '02-01-2022', 4);
insert into NOTA values (371, 'evaluare', 27827, 17, '13-04-2022', 5);
insert into NOTA values (1229, 'teza', 66790, 18, '12-09-2022', 3);
insert into NOTA values (509, 'examen', 80557, 14, '01-06-2022', 4);
insert into NOTA values (1169, 'evaluare', 69929, 5, '03-04-2022', 1);
insert into NOTA values (118, 'activitate independenta', 42853, 7, '19-07-2022', 4);
insert into NOTA values (815, 'activitate independenta', 41056, 20, '01-06-2022', 10);
insert into NOTA values (697, 'test', 64514, 6, '04-08-2022', 2);
insert into NOTA values (1231, 'test', 87892, 5, '09-10-2022', 9);
insert into NOTA values (1576, 'teza', 10575, 8, '01-09-2022', 4);
insert into NOTA values (1802, 'activitate independenta', 97049, 16, '01-11-2022', 1);
insert into NOTA values (13, 'activitate independenta', 41915, 19, '28-08-2022', 9);
insert into NOTA values (1215, 'evaluare', 71224, 14, '01-05-2022', 10);
insert into NOTA values (297, 'test', 79766, 11, '08-03-2022', 1);
insert into NOTA values (357, 'activitate independenta', 13200, 16, '25-08-2022', 2);
insert into NOTA values (304, 'evaluare', 78878, 15, '14-08-2022', 5);
insert into NOTA values (14, 'evaluare', 66790, 10, '03-08-2022', 1);
insert into NOTA values (1812, 'test', 79989, 5, '27-12-2022', 1);
insert into NOTA values (581, 'examen', 85447, 8, '12-05-2022', 5);
insert into NOTA values (1352, 'test', 32887, 4, '04-07-2022', 6);
insert into NOTA values (1247, 'evaluare', 26503, 1, '29-06-2022', 1);
insert into NOTA values (678, 'test', 54270, 9, '14-02-2022', 3);
insert into NOTA values (23, 'activitate independenta', 80663, 5, '05-11-2022', 7);
insert into NOTA values (1889, 'evaluare finala', 73805, 2, '01-08-2022', 7);
insert into NOTA values (1932, 'test', 30497, 13, '22-12-2022', 6);
insert into NOTA values (909, 'evaluare', 80663, 20, '14-10-2022', 5);
insert into NOTA values (56, 'teza', 58914, 17, '18-05-2022', 5);
insert into NOTA values (744, 'evaluare', 32932, 16, '02-06-2022', 1);
insert into NOTA values (1903, 'test', 37880, 5, '21-10-2022', 1);
insert into NOTA values (487, 'teza', 15269, 18, '03-04-2022', 6);
insert into NOTA values (68, 'teza', 59829, 4, '17-07-2022', 3);
insert into NOTA values (1113, 'test', 74966, 7, '28-12-2022', 1);
insert into NOTA values (1425, 'test', 91566, 10, '29-10-2022', 7);
insert into NOTA values (313, 'test', 18985, 10, '24-08-2022', 8);
insert into NOTA values (413, 'evaluare finala', 93071, 8, '27-05-2022', 8);
insert into NOTA values (1543, 'test', 78084, 19, '28-06-2022', 8);
insert into NOTA values (1228, 'activitate independenta', 71447, 20, '08-09-2022', 10);
insert into NOTA values (567, 'evaluare', 52379, 3, '10-05-2022', 3);
insert into NOTA values (703, 'teza', 39639, 19, '16-12-2022', 10);
insert into NOTA values (115, 'teza', 68054, 7, '18-07-2022', 3);
insert into NOTA values (489, 'evaluare finala', 34285, 11, '20-04-2022', 5);
insert into NOTA values (1583, 'examen', 37250, 6, '14-07-2022', 4);
insert into NOTA values (823, 'evaluare', 32131, 9, '10-08-2022', 1);
insert into NOTA values (1595, 'teza', 37156, 17, '12-11-2022', 5);
insert into NOTA values (1915, 'evaluare', 66790, 13, '07-07-2022', 3);
insert into NOTA values (88, 'test', 76959, 2, '12-05-2022', 10);
insert into NOTA values (207, 'examen', 59054, 2, '18-08-2022', 2);
insert into NOTA values (1515, 'teza', 23630, 1, '19-06-2022', 5);
insert into NOTA values (1477, 'activitate independenta', 95309, 17, '06-09-2022', 1);
insert into NOTA values (677, 'test', 20134, 12, '18-08-2022', 3);
insert into NOTA values (1762, 'activitate independenta', 37880, 17, '06-06-2022', 10);
insert into NOTA values (773, 'evaluare', 63531, 8, '28-09-2022', 3);
insert into NOTA values (1381, 'test', 45754, 19, '07-06-2022', 3);
insert into NOTA values (830, 'teza', 85575, 2, '01-04-2022', 8);
insert into NOTA values (426, 'examen', 24496, 13, '08-03-2022', 3);
insert into NOTA values (862, 'teza', 42980, 7, '10-06-2022', 2);
insert into NOTA values (263, 'examen', 92504, 6, '11-02-2022', 2);
insert into NOTA values (1933, 'activitate independenta', 48303, 1, '04-09-2022', 2);
insert into NOTA values (930, 'activitate independenta', 37250, 19, '08-04-2022', 7);
insert into NOTA values (999, 'evaluare', 87780, 1, '01-01-2022', 10);
insert into NOTA values (1877, 'evaluare', 48303, 20, '28-02-2022', 6);
insert into NOTA values (21, 'test', 97724, 4, '08-06-2022', 7);
insert into NOTA values (705, 'test', 50327, 19, '21-03-2022', 4);
insert into NOTA values (643, 'examen', 34961, 13, '29-04-2022', 4);
insert into NOTA values (560, 'evaluare finala', 59985, 3, '24-01-2022', 3);
insert into NOTA values (1075, 'examen', 93071, 17, '17-03-2022', 5);
insert into NOTA values (276, 'activitate independenta', 58035, 20, '20-02-2022', 1);
insert into NOTA values (1719, 'evaluare finala', 49858, 4, '21-03-2022', 5);
insert into NOTA values (588, 'teza', 85447, 20, '21-01-2022', 8);
insert into NOTA values (29, 'activitate independenta', 85575, 10, '01-09-2022', 3);
insert into NOTA values (1174, 'test', 86053, 16, '11-07-2022', 1);
insert into NOTA values (665, 'teza', 11702, 2, '01-01-2022', 1);
insert into NOTA values (1716, 'teza', 41542, 17, '13-07-2022', 8);
insert into NOTA values (795, 'activitate independenta', 49858, 7, '27-06-2022', 2);
insert into NOTA values (1245, 'evaluare', 78878, 18, '24-12-2022', 9);
insert into NOTA values (1810, 'test', 96162, 11, '11-12-2022', 3);
insert into NOTA values (766, 'teza', 37250, 4, '14-02-2022', 3);
insert into NOTA values (317, 'teza', 67084, 8, '04-08-2022', 5);
insert into NOTA values (1320, 'evaluare finala', 65478, 9, '06-12-2022', 1);
insert into NOTA values (232, 'evaluare finala', 11400, 11, '23-09-2022', 3);
insert into NOTA values (652, 'teza', 76700, 3, '06-01-2022', 5);
insert into NOTA values (1397, 'evaluare', 34763, 12, '09-06-2022', 1);
insert into NOTA values (1951, 'test', 12276, 1, '04-04-2022', 6);
insert into NOTA values (1257, 'activitate independenta', 68716, 8, '01-08-2022', 1);
insert into NOTA values (793, 'test', 67084, 3, '04-03-2022', 2);
insert into NOTA values (1087, 'evaluare finala', 53992, 1, '04-10-2022', 7);
insert into NOTA values (1391, 'test', 41056, 1, '13-05-2022', 3);
insert into NOTA values (1815, 'evaluare', 32887, 19, '01-08-2022', 7);
insert into NOTA values (1035, 'activitate independenta', 76700, 20, '28-01-2022', 8);
insert into NOTA values (46, 'test', 13200, 8, '06-08-2022', 3);
insert into NOTA values (1763, 'evaluare', 30736, 1, '19-04-2022', 1);
insert into NOTA values (900, 'examen', 31898, 12, '29-10-2022', 7);
insert into NOTA values (465, 'examen', 76700, 19, '17-08-2022', 7);
insert into NOTA values (1370, 'teza', 76297, 1, '11-04-2022', 9);
insert into NOTA values (479, 'evaluare finala', 37156, 1, '10-09-2022', 4);
insert into NOTA values (437, 'examen', 54270, 7, '11-05-2022', 8);
insert into NOTA values (1029, 'evaluare', 59829, 7, '20-08-2022', 8);
insert into NOTA values (1502, 'evaluare finala', 32129, 8, '26-04-2022', 10);
insert into NOTA values (1739, 'evaluare finala', 70793, 12, '19-04-2022', 8);
insert into NOTA values (574, 'activitate independenta', 60725, 11, '20-11-2022', 8);
insert into NOTA values (363, 'activitate independenta', 82246, 10, '21-02-2022', 3);
insert into NOTA values (272, 'evaluare', 37880, 9, '12-01-2022', 2);
insert into NOTA values (912, 'examen', 50210, 1, '14-04-2022', 1);
insert into NOTA values (78, 'evaluare', 79243, 9, '21-01-2022', 5);
insert into NOTA values (989, 'test', 74535, 10, '16-04-2022', 10);
insert into NOTA values (278, 'test', 85447, 4, '01-06-2022', 9);
insert into NOTA values (257, 'activitate independenta', 93378, 2, '10-02-2022', 1);
insert into NOTA values (618, 'test', 81003, 12, '16-11-2022', 6);
insert into NOTA values (609, 'teza', 66790, 3, '06-02-2022', 1);
insert into NOTA values (1976, 'examen', 20134, 12, '18-06-2022', 6);
insert into NOTA values (1988, 'evaluare finala', 26989, 14, '27-04-2022', 3);
insert into NOTA values (514, 'examen', 35283, 20, '14-03-2022', 6);
insert into NOTA values (1474, 'examen', 77632, 17, '24-06-2022', 5);
insert into NOTA values (189, 'activitate independenta', 79308, 7, '06-08-2022', 2);
insert into NOTA values (1449, 'evaluare', 30736, 4, '01-09-2022', 2);
insert into NOTA values (460, 'examen', 86601, 8, '26-12-2022', 8);
insert into NOTA values (1344, 'evaluare finala', 17661, 17, '27-03-2022', 9);
insert into NOTA values (1354, 'activitate independenta', 33799, 15, '02-08-2022', 1);
insert into NOTA values (1100, 'teza', 86557, 15, '18-02-2022', 6);
insert into NOTA values (1267, 'examen', 69300, 11, '21-02-2022', 5);
insert into NOTA values (1661, 'evaluare', 13170, 5, '14-02-2022', 3);
insert into NOTA values (536, 'activitate independenta', 69298, 10, '10-12-2022', 3);
insert into NOTA values (279, 'examen', 79107, 20, '20-03-2022', 9);
insert into NOTA values (1099, 'examen', 91433, 3, '14-10-2022', 6);
insert into NOTA values (958, 'test', 34008, 11, '25-09-2022', 2);
insert into NOTA values (1520, 'examen', 86601, 3, '27-10-2022', 8);
insert into NOTA values (1825, 'evaluare', 93071, 12, '08-06-2022', 8);
insert into NOTA values (184, 'teza', 11400, 1, '18-01-2022', 2);
insert into NOTA values (143, 'test', 70793, 20, '25-10-2022', 1);
insert into NOTA values (510, 'test', 59054, 7, '14-01-2022', 8);
insert into NOTA values (856, 'evaluare', 32129, 13, '10-02-2022', 5);
insert into NOTA values (1490, 'activitate independenta', 79243, 2, '23-03-2022', 5);
insert into NOTA values (529, 'examen', 23455, 2, '16-10-2022', 2);
insert into NOTA values (1410, 'examen', 51581, 9, '16-03-2022', 3);
insert into NOTA values (785, 'activitate independenta', 66790, 4, '06-04-2022', 2);
insert into NOTA values (1785, 'activitate independenta', 15687, 5, '05-07-2022', 1);
insert into NOTA values (1720, 'activitate independenta', 64514, 11, '03-08-2022', 5);
insert into NOTA values (258, 'teza', 50327, 15, '25-04-2022', 2);
insert into NOTA values (321, 'examen', 25275, 11, '12-11-2022', 5);
insert into NOTA values (706, 'evaluare finala', 12930, 10, '01-11-2022', 5);
insert into NOTA values (1752, 'examen', 59573, 3, '18-12-2022', 2);
insert into NOTA values (1006, 'evaluare finala', 90430, 2, '28-10-2022', 8);
insert into NOTA values (1242, 'evaluare', 82246, 13, '14-11-2022', 5);
insert into NOTA values (1808, 'activitate independenta', 32887, 5, '01-03-2022', 3);
insert into NOTA values (247, 'teza', 32932, 16, '28-05-2022', 5);
insert into NOTA values (982, 'test', 59573, 17, '09-07-2022', 5);
insert into NOTA values (1374, 'evaluare', 27827, 14, '03-12-2022', 10);
insert into NOTA values (1725, 'activitate independenta', 13170, 19, '26-10-2022', 2);
insert into NOTA values (1467, 'evaluare finala', 52700, 12, '22-04-2022', 3);
insert into NOTA values (894, 'teza', 69929, 9, '26-10-2022', 3);
insert into NOTA values (1691, 'evaluare finala', 41542, 17, '24-03-2022', 7);
insert into NOTA values (1662, 'activitate independenta', 14991, 2, '11-02-2022', 6);
insert into NOTA values (1842, 'activitate independenta', 80557, 13, '20-02-2022', 3);
insert into NOTA values (1620, 'teza', 70793, 10, '26-05-2022', 6);
insert into NOTA values (195, 'activitate independenta', 26503, 4, '26-07-2022', 3);
insert into NOTA values (1012, 'activitate independenta', 58540, 14, '20-06-2022', 2);
insert into NOTA values (804, 'evaluare', 58914, 2, '03-12-2022', 9);
insert into NOTA values (628, 'teza', 51581, 19, '11-09-2022', 3);
insert into NOTA values (1128, 'examen', 58914, 11, '27-12-2022', 5);
insert into NOTA values (1274, 'evaluare', 45754, 14, '15-10-2022', 8);
insert into NOTA values (1141, 'evaluare finala', 42853, 12, '20-04-2022', 6);
insert into NOTA values (387, 'examen', 41542, 12, '27-07-2022', 9);
insert into NOTA values (1460, 'activitate independenta', 33799, 10, '07-10-2022', 3);
insert into NOTA values (1820, 'evaluare', 61371, 14, '21-03-2022', 8);
insert into NOTA values (802, 'activitate independenta', 52047, 4, '12-12-2022', 6);
insert into NOTA values (844, 'test', 71170, 17, '28-12-2022', 7);
insert into NOTA values (835, 'test', 76700, 7, '20-09-2022', 3);
insert into NOTA values (1797, 'examen', 59825, 7, '13-03-2022', 5);
insert into NOTA values (1617, 'evaluare', 60725, 7, '09-06-2022', 3);
insert into NOTA values (1920, 'activitate independenta', 26599, 18, '02-10-2022', 2);
insert into NOTA values (1534, 'test', 45754, 15, '22-01-2022', 8);
insert into NOTA values (187, 'test', 41050, 13, '11-03-2022', 9);
insert into NOTA values (898, 'examen', 49878, 18, '01-01-2022', 2);
insert into NOTA values (1675, 'test', 63531, 18, '15-05-2022', 3);
insert into NOTA values (1375, 'evaluare finala', 39499, 2, '24-06-2022', 8);
insert into NOTA values (1180, 'test', 13931, 17, '23-05-2022', 4);
insert into NOTA values (420, 'test', 81244, 10, '02-03-2022', 5);
insert into NOTA values (1098, 'evaluare', 47168, 15, '15-04-2022', 9);
insert into NOTA values (914, 'test', 70793, 19, '08-01-2022', 4);
insert into NOTA values (342, 'test', 41050, 20, '03-04-2022', 9);
insert into NOTA values (294, 'evaluare', 93748, 13, '18-11-2022', 1);
insert into NOTA values (520, 'evaluare', 60798, 17, '02-04-2022', 8);
insert into NOTA values (807, 'activitate independenta', 26599, 4, '18-05-2022', 3);
insert into NOTA values (866, 'test', 66790, 7, '15-09-2022', 5);
insert into NOTA values (662, 'activitate independenta', 64514, 18, '13-11-2022', 1);
insert into NOTA values (112, 'evaluare finala', 71447, 10, '29-12-2022', 3);
insert into NOTA values (1129, 'examen', 51581, 17, '29-10-2022', 2);
insert into NOTA values (156, 'test', 91433, 13, '21-12-2022', 6);
insert into NOTA values (1210, 'evaluare finala', 52047, 20, '21-07-2022', 3);
insert into NOTA values (1537, 'test', 96162, 8, '17-12-2022', 9);
insert into NOTA values (754, 'teza', 39499, 16, '17-05-2022', 7);
insert into NOTA values (196, 'evaluare finala', 42980, 14, '03-01-2022', 7);
insert into NOTA values (828, 'evaluare finala', 30549, 2, '22-10-2022', 3);
insert into NOTA values (379, 'test', 27022, 17, '20-08-2022', 1);
insert into NOTA values (328, 'activitate independenta', 48303, 11, '05-07-2022', 6);
insert into NOTA values (1112, 'teza', 59755, 16, '02-04-2022', 7);
insert into NOTA values (1464, 'test', 59755, 3, '14-10-2022', 10);
insert into NOTA values (772, 'evaluare finala', 79989, 9, '26-08-2022', 4);
insert into NOTA values (416, 'examen', 80663, 3, '28-12-2022', 5);
insert into NOTA values (1244, 'examen', 10575, 18, '01-11-2022', 5);
insert into NOTA values (892, 'examen', 97724, 7, '28-03-2022', 1);
insert into NOTA values (1780, 'evaluare finala', 59054, 20, '13-09-2022', 8);
insert into NOTA values (1430, 'test', 59825, 4, '07-04-2022', 10);
insert into NOTA values (193, 'activitate independenta', 87780, 16, '16-08-2022', 6);
insert into NOTA values (566, 'examen', 73805, 12, '23-08-2022', 5);
insert into NOTA values (599, 'activitate independenta', 42980, 7, '13-09-2022', 2);
insert into NOTA values (436, 'teza', 35283, 12, '29-03-2022', 5);
insert into NOTA values (1132, 'activitate independenta', 41542, 17, '18-01-2022', 6);
insert into NOTA values (1641, 'activitate independenta', 52047, 19, '29-11-2022', 2);
insert into NOTA values (398, 'teza', 48303, 20, '21-10-2022', 2);
insert into NOTA values (1330, 'teza', 42980, 20, '21-03-2022', 6);
insert into NOTA values (31, 'test', 93071, 8, '07-12-2022', 2);
insert into NOTA values (1325, 'evaluare', 71224, 3, '15-04-2022', 7);
insert into NOTA values (1845, 'examen', 17661, 18, '06-05-2022', 10);
insert into NOTA values (492, 'teza', 52700, 14, '28-09-2022', 3);
insert into NOTA values (1193, 'examen', 19274, 8, '13-10-2022', 6);
insert into NOTA values (885, 'evaluare', 87892, 7, '10-07-2022', 4);
insert into NOTA values (20, 'test', 86601, 1, '21-06-2022', 2);
insert into NOTA values (1737, 'evaluare finala', 27911, 12, '11-08-2022', 2);
insert into NOTA values (1013, 'test', 80557, 1, '29-10-2022', 1);
insert into NOTA values (1998, 'evaluare', 12019, 9, '12-12-2022', 6);
insert into NOTA values (1332, 'evaluare finala', 80663, 13, '13-05-2022', 1);
insert into NOTA values (105, 'examen', 76700, 16, '13-11-2022', 8);
insert into NOTA values (1993, 'activitate independenta', 26503, 5, '09-12-2022', 3);
insert into NOTA values (355, 'teza', 51056, 5, '05-12-2022', 8);
insert into NOTA values (391, 'activitate independenta', 93378, 16, '28-06-2022', 8);
insert into NOTA values (1488, 'teza', 69300, 12, '08-01-2022', 2);
insert into NOTA values (517, 'activitate independenta', 70793, 1, '11-03-2022', 3);
insert into NOTA values (1791, 'activitate independenta', 18580, 7, '19-10-2022', 1);
insert into NOTA values (1979, 'evaluare finala', 56729, 16, '13-04-2022', 8);
insert into NOTA values (1548, 'examen', 52047, 4, '24-09-2022', 2);
insert into NOTA values (829, 'evaluare finala', 52379, 7, '13-07-2022', 2);
insert into NOTA values (490, 'teza', 58540, 14, '01-09-2022', 8);
insert into NOTA values (571, 'evaluare finala', 96162, 10, '28-08-2022', 4);
insert into NOTA values (1255, 'evaluare', 92384, 12, '27-05-2022', 7);
insert into NOTA values (709, 'evaluare', 41056, 2, '24-09-2022', 3);
insert into NOTA values (1584, 'test', 11400, 10, '09-09-2022', 6);
insert into NOTA values (1348, 'evaluare finala', 79308, 12, '10-05-2022', 9);
insert into NOTA values (1529, 'activitate independenta', 18177, 14, '19-10-2022', 1);
insert into NOTA values (1333, 'teza', 33799, 9, '27-10-2022', 4);
insert into NOTA values (1291, 'activitate independenta', 46821, 16, '29-05-2022', 9);
insert into NOTA values (973, 'examen', 79243, 14, '24-12-2022', 10);
insert into NOTA values (692, 'teza', 81244, 16, '25-07-2022', 3);
insert into NOTA values (559, 'test', 24529, 19, '03-10-2022', 3);
insert into NOTA values (1830, 'evaluare', 51581, 11, '27-04-2022', 8);
insert into NOTA values (647, 'evaluare finala', 70793, 8, '07-11-2022', 7);
insert into NOTA values (916, 'evaluare finala', 96342, 13, '07-03-2022', 2);
insert into NOTA values (160, 'teza', 51581, 14, '12-07-2022', 6);
insert into NOTA values (740, 'teza', 59321, 13, '01-01-2022', 10);
insert into NOTA values (1814, 'examen', 26503, 10, '05-11-2022', 6);
insert into NOTA values (155, 'evaluare', 25275, 2, '12-11-2022', 9);
insert into NOTA values (1776, 'evaluare', 41542, 18, '16-01-2022', 4);
insert into NOTA values (1211, 'evaluare', 45754, 8, '05-09-2022', 3);
insert into NOTA values (435, 'teza', 53388, 9, '20-06-2022', 3);
insert into NOTA values (876, 'teza', 41050, 4, '20-01-2022', 4);
insert into NOTA values (1678, 'teza', 37725, 10, '24-05-2022', 7);
insert into NOTA values (7, 'evaluare finala', 32129, 20, '27-04-2022', 5);
insert into NOTA values (1164, 'evaluare', 60725, 3, '22-10-2022', 1);
insert into NOTA values (214, 'test', 13200, 18, '22-05-2022', 5);
insert into NOTA values (1746, 'teza', 46399, 11, '26-06-2022', 6);
insert into NOTA values (1985, 'test', 33279, 4, '14-11-2022', 4);
insert into NOTA values (1090, 'activitate independenta', 79243, 3, '14-11-2022', 5);
insert into NOTA values (1509, 'test', 59985, 18, '01-04-2022', 10);
insert into NOTA values (1795, 'evaluare finala', 12019, 16, '17-02-2022', 6);
insert into NOTA values (183, 'activitate independenta', 20449, 9, '11-01-2022', 2);
insert into NOTA values (1761, 'examen', 58540, 12, '18-10-2022', 10);
insert into NOTA values (867, 'evaluare finala', 19274, 10, '28-09-2022', 6);
insert into NOTA values (41, 'evaluare finala', 42980, 16, '04-07-2022', 3);
insert into NOTA values (1278, 'evaluare finala', 59825, 10, '07-08-2022', 10);
insert into NOTA values (239, 'evaluare finala', 99911, 15, '04-08-2022', 9);
insert into NOTA values (881, 'test', 60725, 17, '25-03-2022', 7);
insert into NOTA values (1009, 'evaluare finala', 30730, 15, '01-12-2022', 4);
insert into NOTA values (1772, 'activitate independenta', 95188, 8, '07-06-2022', 4);
insert into NOTA values (1412, 'activitate independenta', 37671, 20, '22-03-2022', 1);
insert into NOTA values (1781, 'test', 47168, 17, '22-05-2022', 3);
insert into NOTA values (1140, 'evaluare finala', 91463, 5, '26-11-2022', 7);
insert into NOTA values (1266, 'activitate independenta', 59755, 8, '12-09-2022', 2);
insert into NOTA values (295, 'test', 41050, 5, '15-07-2022', 5);
insert into NOTA values (1715, 'evaluare finala', 30730, 3, '16-12-2022', 8);
insert into NOTA values (1403, 'activitate independenta', 71170, 11, '14-04-2022', 4);
insert into NOTA values (1901, 'examen', 34008, 3, '14-02-2022', 8);
insert into NOTA values (1586, 'evaluare finala', 84475, 13, '20-12-2022', 6);
insert into NOTA values (483, 'examen', 59573, 17, '17-04-2022', 1);
insert into NOTA values (318, 'activitate independenta', 18177, 20, '11-04-2022', 3);
insert into NOTA values (345, 'evaluare finala', 54270, 11, '01-04-2022', 3);
insert into NOTA values (486, 'examen', 84873, 12, '20-12-2022', 5);
insert into NOTA values (2, 'teza', 26599, 7, '06-02-2022', 1);
insert into NOTA values (63, 'examen', 84475, 18, '11-04-2022', 3);
insert into NOTA values (1416, 'activitate independenta', 58540, 10, '12-08-2022', 2);
insert into NOTA values (1259, 'examen', 84498, 20, '20-08-2022', 8);
insert into NOTA values (1764, 'evaluare', 64514, 16, '14-10-2022', 9);
insert into NOTA values (237, 'evaluare finala', 32887, 5, '17-06-2022', 4);
insert into NOTA values (636, 'activitate independenta', 11594, 13, '26-04-2022', 3);
insert into NOTA values (1466, 'evaluare finala', 23455, 3, '03-07-2022', 4);
insert into NOTA values (784, 'test', 96996, 16, '01-10-2022', 7);
insert into NOTA values (169, 'evaluare finala', 17661, 19, '14-07-2022', 6);
insert into NOTA values (320, 'evaluare', 76700, 5, '15-09-2022', 6);
insert into NOTA values (1523, 'examen', 70793, 20, '10-08-2022', 6);
insert into NOTA values (969, 'evaluare', 25275, 4, '12-09-2022', 8);
insert into NOTA values (265, 'examen', 70793, 3, '18-01-2022', 1);
insert into NOTA values (1188, 'examen', 95640, 11, '15-04-2022', 9);
insert into NOTA values (720, 'examen', 84873, 16, '25-02-2022', 10);
insert into NOTA values (1079, 'evaluare finala', 73805, 18, '24-11-2022', 1);
insert into NOTA values (414, 'test', 81003, 18, '29-06-2022', 8);
insert into NOTA values (244, 'activitate independenta', 53388, 20, '07-11-2022', 10);
insert into NOTA values (83, 'activitate independenta', 10575, 2, '19-03-2022', 4);
insert into NOTA values (545, 'examen', 52047, 12, '28-12-2022', 7);
insert into NOTA values (984, 'examen', 74535, 5, '28-03-2022', 3);
insert into NOTA values (1868, 'examen', 42980, 14, '10-09-2022', 1);
insert into NOTA values (1025, 'activitate independenta', 68054, 15, '25-01-2022', 9);
insert into NOTA values (1457, 'activitate independenta', 18580, 3, '15-11-2022', 10);
insert into NOTA values (134, 'test', 79107, 14, '27-09-2022', 2);
insert into NOTA values (1792, 'activitate independenta', 24529, 10, '27-07-2022', 9);
insert into NOTA values (1094, 'activitate independenta', 60798, 3, '09-01-2022', 2);
insert into NOTA values (472, 'evaluare', 30736, 13, '13-10-2022', 7);
insert into NOTA values (410, 'examen', 78084, 13, '18-06-2022', 7);
insert into NOTA values (254, 'examen', 74535, 20, '20-03-2022', 5);
insert into NOTA values (732, 'activitate independenta', 27720, 2, '25-12-2022', 4);
insert into NOTA values (242, 'examen', 34961, 16, '10-12-2022', 1);
insert into NOTA values (601, 'activitate independenta', 97706, 9, '20-10-2022', 3);
insert into NOTA values (462, 'teza', 51581, 4, '12-05-2022', 2);
insert into NOTA values (226, 'teza', 20134, 8, '26-03-2022', 9);
insert into NOTA values (1721, 'teza', 15687, 17, '02-07-2022', 2);
insert into NOTA values (1704, 'evaluare', 97049, 14, '01-08-2022', 6);
insert into NOTA values (448, 'teza', 96342, 2, '13-08-2022', 1);
insert into NOTA values (1427, 'test', 19274, 1, '01-09-2022', 8);
insert into NOTA values (311, 'teza', 59573, 11, '09-10-2022', 7);
insert into NOTA values (725, 'test', 92504, 17, '20-06-2022', 7);
insert into NOTA values (871, 'teza', 33799, 10, '18-06-2022', 7);
insert into NOTA values (1519, 'teza', 93071, 12, '14-07-2022', 3);
insert into NOTA values (1518, 'test', 77928, 5, '26-11-2022', 10);
insert into NOTA values (1310, 'examen', 60725, 10, '22-11-2022', 3);
insert into NOTA values (1124, 'activitate independenta', 34008, 2, '28-02-2022', 6);
insert into NOTA values (1908, 'examen', 77632, 3, '20-02-2022', 4);
insert into NOTA values (1643, 'examen', 70839, 19, '11-07-2022', 5);
insert into NOTA values (1020, 'evaluare', 37880, 10, '19-12-2022', 9);
insert into NOTA values (1956, 'evaluare', 58035, 13, '07-08-2022', 8);
insert into NOTA values (1103, 'teza', 95640, 16, '10-02-2022', 7);
insert into NOTA values (1372, 'activitate independenta', 27827, 2, '18-09-2022', 4);
insert into NOTA values (1152, 'examen', 32131, 15, '11-10-2022', 6);
insert into NOTA values (61, 'activitate independenta', 35283, 20, '25-03-2022', 4);
insert into NOTA values (672, 'evaluare finala', 80663, 10, '07-11-2022', 1);
insert into NOTA values (1026, 'evaluare', 44638, 15, '16-03-2022', 2);
insert into NOTA values (1353, 'evaluare', 76297, 18, '16-07-2022', 7);
insert into NOTA values (933, 'activitate independenta', 46399, 13, '29-05-2022', 4);
insert into NOTA values (457, 'activitate independenta', 65478, 10, '17-06-2022', 9);
insert into NOTA values (1419, 'activitate independenta', 44638, 3, '07-06-2022', 1);
insert into NOTA values (749, 'teza', 91463, 17, '25-06-2022', 2);
insert into NOTA values (1429, 'evaluare finala', 34008, 8, '28-04-2022', 6);
insert into NOTA values (775, 'activitate independenta', 63531, 12, '24-06-2022', 2);
insert into NOTA values (57, 'evaluare finala', 91463, 9, '29-07-2022', 5);
insert into NOTA values (1496, 'teza', 85447, 5, '03-10-2022', 6);
insert into NOTA values (1777, 'activitate independenta', 23630, 16, '07-10-2022', 3);
insert into NOTA values (422, 'evaluare finala', 19852, 1, '20-03-2022', 10);
insert into NOTA values (15, 'evaluare finala', 56729, 16, '05-11-2022', 5);
insert into NOTA values (1740, 'activitate independenta', 68054, 5, '26-03-2022', 10);
insert into NOTA values (1588, 'examen', 52700, 6, '17-07-2022', 6);
insert into NOTA values (199, 'evaluare', 35283, 17, '08-03-2022', 1);
insert into NOTA values (1358, 'evaluare', 33279, 1, '04-01-2022', 7);
insert into NOTA values (578, 'evaluare', 85447, 14, '09-08-2022', 9);
insert into NOTA values (1363, 'evaluare finala', 27720, 9, '07-11-2022', 8);
insert into NOTA values (642, 'test', 59755, 4, '29-12-2022', 3);
insert into NOTA values (1682, 'evaluare', 37156, 18, '25-12-2022', 6);
insert into NOTA values (580, 'teza', 74966, 16, '06-02-2022', 4);
insert into NOTA values (1941, 'evaluare', 87892, 9, '04-09-2022', 8);
insert into NOTA values (1039, 'activitate independenta', 58540, 11, '05-02-2022', 7);
insert into NOTA values (1960, 'examen', 61371, 6, '29-07-2022', 7);
insert into NOTA values (55, 'evaluare finala', 19274, 10, '14-09-2022', 7);
insert into NOTA values (528, 'test', 20449, 2, '06-02-2022', 10);
insert into NOTA values (811, 'activitate independenta', 67084, 11, '05-06-2022', 3);
insert into NOTA values (1535, 'evaluare', 37725, 19, '01-03-2022', 6);
insert into NOTA values (1166, 'examen', 81003, 8, '18-11-2022', 6);
insert into NOTA values (1273, 'activitate independenta', 27911, 1, '17-05-2022', 9);
insert into NOTA values (1123, 'activitate independenta', 41050, 16, '07-12-2022', 8);
insert into NOTA values (466, 'teza', 81003, 1, '14-03-2022', 5);
insert into NOTA values (819, 'examen', 24529, 19, '23-03-2022', 6);
insert into NOTA values (694, 'evaluare finala', 70839, 7, '06-12-2022', 7);
insert into NOTA values (813, 'evaluare finala', 52047, 2, '16-04-2022', 2);
insert into NOTA values (378, 'evaluare', 87780, 8, '09-02-2022', 10);
insert into NOTA values (1138, 'evaluare', 18985, 11, '12-10-2022', 1);
insert into NOTA values (1498, 'examen', 73805, 14, '19-03-2022', 1);
insert into NOTA values (1299, 'evaluare finala', 20134, 8, '05-11-2022', 1);
insert into NOTA values (404, 'activitate independenta', 13170, 6, '25-10-2022', 1);
insert into NOTA values (1671, 'evaluare', 71886, 4, '28-02-2022', 3);
insert into NOTA values (1055, 'test', 96162, 19, '23-01-2022', 1);
insert into NOTA values (1628, 'teza', 37725, 1, '07-04-2022', 8);
insert into NOTA values (1873, 'test', 69929, 3, '20-10-2022', 10);
insert into NOTA values (1554, 'test', 60725, 18, '17-06-2022', 9);
insert into NOTA values (902, 'evaluare', 86557, 19, '09-09-2022', 7);
insert into NOTA values (1063, 'evaluare', 79989, 2, '17-04-2022', 9);
insert into NOTA values (493, 'test', 99911, 13, '17-01-2022', 6);
insert into NOTA values (1030, 'teza', 32131, 9, '15-02-2022', 6);
insert into NOTA values (1893, 'evaluare', 30549, 9, '03-02-2022', 4);
insert into NOTA values (1813, 'evaluare', 46821, 15, '05-11-2022', 7);
insert into NOTA values (1836, 'test', 79989, 11, '21-01-2022', 10);
insert into NOTA values (1927, 'teza', 94765, 2, '18-04-2022', 3);
insert into NOTA values (556, 'examen', 35731, 18, '08-01-2022', 8);
insert into NOTA values (1504, 'test', 41915, 6, '08-06-2022', 3);
insert into NOTA values (405, 'teza', 35731, 20, '13-08-2022', 10);
insert into NOTA values (213, 'evaluare finala', 73805, 14, '11-04-2022', 10);
insert into NOTA values (425, 'test', 92504, 13, '14-08-2022', 8);
insert into NOTA values (1080, 'evaluare', 45754, 16, '20-02-2022', 1);
insert into NOTA values (1829, 'examen', 79766, 19, '22-07-2022', 8);
insert into NOTA values (1997, 'examen', 24529, 15, '07-03-2022', 1);
insert into NOTA values (109, 'activitate independenta', 35731, 17, '06-10-2022', 3);
insert into NOTA values (872, 'test', 59829, 3, '10-08-2022', 2);
insert into NOTA values (809, 'examen', 19852, 2, '07-01-2022', 6);
insert into NOTA values (676, 'activitate independenta', 69298, 4, '20-12-2022', 3);
insert into NOTA values (607, 'examen', 46399, 11, '22-10-2022', 4);
insert into NOTA values (1335, 'activitate independenta', 27022, 13, '06-07-2022', 10);
insert into NOTA values (1655, 'test', 11400, 12, '14-11-2022', 8);
insert into NOTA values (1667, 'evaluare', 71170, 3, '29-10-2022', 3);
insert into NOTA values (1714, 'teza', 41542, 10, '23-07-2022', 8);
insert into NOTA values (613, 'test', 61371, 11, '01-10-2022', 4);
insert into NOTA values (1234, 'evaluare finala', 12276, 13, '17-10-2022', 5);
insert into NOTA values (1748, 'evaluare finala', 32651, 5, '18-01-2022', 2);
insert into NOTA values (1105, 'evaluare finala', 32887, 1, '04-01-2022', 6);
insert into NOTA values (117, 'evaluare finala', 34763, 16, '07-12-2022', 2);
insert into NOTA values (693, 'test', 67084, 2, '18-02-2022', 9);
insert into NOTA values (1288, 'evaluare finala', 33799, 14, '19-10-2022', 10);
insert into NOTA values (138, 'activitate independenta', 71170, 14, '07-03-2022', 7);
insert into NOTA values (1181, 'test', 64514, 20, '02-07-2022', 7);
insert into NOTA values (1573, 'teza', 15269, 16, '12-04-2022', 8);
insert into NOTA values (836, 'evaluare', 78084, 20, '11-11-2022', 9);
insert into NOTA values (421, 'examen', 51056, 1, '24-04-2022', 1);
insert into NOTA values (936, 'examen', 84475, 6, '23-05-2022', 10);
insert into NOTA values (873, 'activitate independenta', 76297, 3, '05-03-2022', 1);
insert into NOTA values (343, 'examen', 11594, 5, '20-08-2022', 3);
insert into NOTA values (1382, 'test', 37156, 15, '02-03-2022', 8);
insert into NOTA values (596, 'teza', 97049, 12, '29-11-2022', 9);
insert into NOTA values (1686, 'activitate independenta', 30549, 4, '20-01-2022', 8);
insert into NOTA values (1101, 'examen', 41050, 3, '11-06-2022', 7);
insert into NOTA values (1943, 'activitate independenta', 74966, 3, '08-09-2022', 1);
insert into NOTA values (1874, 'activitate independenta', 15269, 19, '24-01-2022', 10);
insert into NOTA values (539, 'teza', 77928, 8, '28-06-2022', 3);
insert into NOTA values (298, 'examen', 32129, 2, '01-01-2022', 7);
insert into NOTA values (1745, 'activitate independenta', 10575, 11, '16-12-2022', 6);
insert into NOTA values (1601, 'evaluare finala', 68054, 18, '16-12-2022', 6);
insert into NOTA values (1264, 'test', 96162, 17, '24-03-2022', 6);
insert into NOTA values (1567, 'examen', 67084, 10, '23-06-2022', 10);
insert into NOTA values (1054, 'activitate independenta', 35283, 12, '08-07-2022', 3);
insert into NOTA values (713, 'evaluare finala', 65744, 4, '11-05-2022', 5);
insert into NOTA values (1872, 'evaluare finala', 87780, 8, '15-10-2022', 4);
insert into NOTA values (1650, 'examen', 86601, 9, '25-12-2022', 10);
insert into NOTA values (1389, 'evaluare', 33799, 20, '16-12-2022', 5);
insert into NOTA values (1439, 'examen', 93748, 16, '18-03-2022', 4);
insert into NOTA values (1149, 'activitate independenta', 19852, 6, '15-08-2022', 9);
insert into NOTA values (1142, 'evaluare', 87892, 1, '02-10-2022', 6);
insert into NOTA values (302, 'evaluare', 71224, 16, '05-09-2022', 3);
insert into NOTA values (1176, 'activitate independenta', 30549, 15, '26-11-2022', 7);
insert into NOTA values (153, 'examen', 27022, 18, '21-10-2022', 2);
insert into NOTA values (592, 'test', 71224, 2, '14-09-2022', 2);
insert into NOTA values (1670, 'evaluare finala', 84475, 3, '05-06-2022', 7);
insert into NOTA values (1453, 'evaluare', 65744, 1, '27-05-2022', 5);
insert into NOTA values (458, 'teza', 47168, 14, '23-03-2022', 8);
insert into NOTA values (1318, 'evaluare', 71886, 4, '01-03-2022', 10);
insert into NOTA values (959, 'teza', 11594, 15, '22-11-2022', 9);
insert into NOTA values (266, 'teza', 71886, 13, '25-10-2022', 3);
insert into NOTA values (424, 'evaluare finala', 58914, 14, '09-02-2022', 2);
insert into NOTA values (1478, 'test', 18177, 9, '04-06-2022', 2);
insert into NOTA values (1321, 'activitate independenta', 20449, 6, '18-08-2022', 5);
insert into NOTA values (1041, 'examen', 37250, 1, '16-09-2022', 5);
insert into NOTA values (1766, 'evaluare', 37671, 17, '16-12-2022', 2);
insert into NOTA values (537, 'teza', 90430, 4, '07-01-2022', 3);
insert into NOTA values (283, 'evaluare finala', 48303, 10, '11-10-2022', 7);
insert into NOTA values (1579, 'test', 79766, 17, '28-12-2022', 1);
insert into NOTA values (94, 'test', 79107, 20, '07-12-2022', 1);
insert into NOTA values (1866, 'evaluare finala', 46399, 9, '23-03-2022', 5);
insert into NOTA values (261, 'evaluare', 32887, 19, '28-10-2022', 9);
insert into NOTA values (1216, 'teza', 23455, 17, '07-03-2022', 4);
insert into NOTA values (542, 'examen', 58914, 5, '19-11-2022', 6);
insert into NOTA values (664, 'evaluare', 11594, 9, '19-05-2022', 9);
insert into NOTA values (893, 'evaluare', 12930, 7, '06-07-2022', 10);
insert into NOTA values (985, 'teza', 32129, 1, '01-08-2022', 10);
insert into NOTA values (1194, 'activitate independenta', 46399, 7, '17-06-2022', 8);
insert into NOTA values (717, 'evaluare finala', 27720, 3, '19-06-2022', 4);
insert into NOTA values (173, 'teza', 76959, 10, '27-09-2022', 3);
insert into NOTA values (205, 'evaluare', 23455, 11, '01-07-2022', 4);
insert into NOTA values (708, 'examen', 59829, 19, '09-08-2022', 7);
insert into NOTA values (1493, 'evaluare finala', 61371, 8, '25-06-2022', 10);
insert into NOTA values (610, 'activitate independenta', 90430, 4, '26-11-2022', 3);
insert into NOTA values (527, 'evaluare', 69298, 16, '12-05-2022', 5);
insert into NOTA values (1994, 'examen', 79308, 12, '05-10-2022', 8);
insert into NOTA values (1296, 'test', 70839, 13, '15-04-2022', 5);
insert into NOTA values (1351, 'evaluare', 32887, 15, '07-09-2022', 10);
insert into NOTA values (212, 'activitate independenta', 39499, 6, '08-09-2022', 6);
insert into NOTA values (821, 'evaluare finala', 34763, 17, '27-02-2022', 4);
insert into NOTA values (1977, 'activitate independenta', 49858, 19, '11-06-2022', 6);
insert into NOTA values (364, 'activitate independenta', 37880, 16, '01-10-2022', 10);
insert into NOTA values (386, 'examen', 27720, 15, '03-04-2022', 6);
insert into NOTA values (30, 'teza', 27720, 15, '16-06-2022', 4);
insert into NOTA values (910, 'evaluare finala', 17661, 1, '13-07-2022', 7);
insert into NOTA values (1108, 'evaluare', 39499, 10, '14-03-2022', 2);
insert into NOTA values (192, 'activitate independenta', 68054, 14, '12-04-2022', 6);
insert into NOTA values (190, 'examen', 46399, 6, '03-04-2022', 10);
insert into NOTA values (928, 'evaluare finala', 44366, 16, '18-07-2022', 4);
insert into NOTA values (1161, 'test', 11702, 12, '09-06-2022', 10);
insert into NOTA values (1357, 'teza', 68716, 13, '26-08-2022', 9);
insert into NOTA values (745, 'activitate independenta', 49349, 7, '23-02-2022', 9);
insert into NOTA values (233, 'evaluare', 27720, 4, '26-11-2022', 4);
insert into NOTA values (1326, 'activitate independenta', 81244, 16, '26-12-2022', 2);
insert into NOTA values (1522, 'teza', 68069, 2, '02-05-2022', 2);
insert into NOTA values (644, 'test', 52379, 7, '02-05-2022', 4);
insert into NOTA values (1097, 'evaluare finala', 59829, 11, '12-02-2022', 7);
insert into NOTA values (1069, 'evaluare', 46821, 8, '13-10-2022', 7);
insert into NOTA values (165, 'examen', 85447, 15, '01-01-2022', 7);
insert into NOTA values (1350, 'test', 79308, 10, '25-11-2022', 10);
insert into NOTA values (917, 'test', 41813, 3, '25-11-2022', 10);
insert into NOTA values (1402, 'teza', 12019, 10, '29-10-2022', 7);
insert into NOTA values (753, 'test', 76700, 18, '25-02-2022', 7);
insert into NOTA values (945, 'teza', 85447, 20, '20-06-2022', 2);
insert into NOTA values (1939, 'evaluare', 81003, 7, '05-09-2022', 1);
insert into NOTA values (1340, 'activitate independenta', 18985, 17, '03-07-2022', 3);
insert into NOTA values (1021, 'test', 23455, 3, '19-06-2022', 6);
insert into NOTA values (1455, 'evaluare finala', 80557, 4, '25-07-2022', 7);
insert into NOTA values (1109, 'test', 93071, 12, '23-05-2022', 2);
insert into NOTA values (540, 'teza', 94765, 3, '25-12-2022', 6);
insert into NOTA values (799, 'teza', 68069, 8, '23-06-2022', 6);
insert into NOTA values (1368, 'test', 30730, 4, '19-08-2022', 6);
insert into NOTA values (1150, 'activitate independenta', 35731, 12, '16-05-2022', 3);
insert into NOTA values (1789, 'examen', 12019, 14, '14-11-2022', 10);
insert into NOTA values (1221, 'test', 79308, 20, '01-09-2022', 1);
insert into NOTA values (1463, 'examen', 27720, 15, '24-08-2022', 9);
insert into NOTA values (1127, 'teza', 23455, 13, '08-06-2022', 2);
insert into NOTA values (827, 'teza', 94765, 7, '24-09-2022', 8);
insert into NOTA values (27, 'activitate independenta', 99911, 14, '16-08-2022', 6);
insert into NOTA values (1553, 'evaluare', 19274, 12, '22-08-2022', 10);
insert into NOTA values (637, 'evaluare', 95309, 17, '23-06-2022', 8);
insert into NOTA values (600, 'teza', 68054, 19, '28-03-2022', 3);
insert into NOTA values (1765, 'test', 91463, 9, '02-02-2022', 1);
insert into NOTA values (1634, 'test', 46821, 16, '13-12-2022', 10);
insert into NOTA values (1294, 'evaluare', 81244, 6, '03-05-2022', 5);
insert into NOTA values (1322, 'evaluare', 87780, 7, '09-07-2022', 6);
insert into NOTA values (1804, 'test', 68054, 10, '26-03-2022', 7);
insert into NOTA values (869, 'test', 76297, 9, '14-11-2022', 2);
insert into NOTA values (1383, 'activitate independenta', 54270, 13, '01-03-2022', 4);
insert into NOTA values (162, 'evaluare finala', 25275, 4, '16-09-2022', 4);
insert into NOTA values (890, 'examen', 11594, 2, '13-02-2022', 3);
insert into NOTA values (1047, 'evaluare finala', 84498, 1, '15-11-2022', 3);
insert into NOTA values (1677, 'evaluare finala', 41050, 20, '29-12-2022', 3);
insert into NOTA values (1824, 'activitate independenta', 46399, 3, '12-07-2022', 10);
insert into NOTA values (1447, 'evaluare finala', 12930, 4, '19-05-2022', 6);
insert into NOTA values (805, 'teza', 71886, 9, '12-08-2022', 8);
insert into NOTA values (646, 'evaluare finala', 97724, 14, '11-01-2022', 1);
insert into NOTA values (1616, 'evaluare', 93378, 19, '01-12-2022', 9);
insert into NOTA values (204, 'activitate independenta', 59825, 9, '23-08-2022', 9);
insert into NOTA values (1052, 'evaluare', 86053, 12, '17-06-2022', 5);
insert into NOTA values (1175, 'test', 42853, 15, '14-06-2022', 6);
insert into NOTA values (839, 'evaluare', 68054, 7, '25-11-2022', 4);
insert into NOTA values (1501, 'teza', 18136, 6, '24-09-2022', 10);
insert into NOTA values (1569, 'test', 26989, 17, '11-04-2022', 2);
insert into NOTA values (1298, 'test', 91433, 14, '12-03-2022', 5);
insert into NOTA values (1022, 'evaluare', 58914, 15, '20-09-2022', 6);
insert into NOTA values (798, 'test', 96162, 20, '11-02-2022', 9);
insert into NOTA values (444, 'test', 84498, 1, '06-10-2022', 3);
insert into NOTA values (1913, 'evaluare', 26599, 2, '28-09-2022', 5);
insert into NOTA values (1196, 'evaluare finala', 18136, 15, '11-11-2022', 6);
insert into NOTA values (69, 'evaluare finala', 18136, 15, '19-06-2022', 7);
insert into NOTA values (1531, 'teza', 24529, 8, '15-05-2022', 3);
insert into NOTA values (1603, 'evaluare', 52700, 14, '29-12-2022', 8);
insert into NOTA values (1556, 'activitate independenta', 93071, 10, '06-07-2022', 3);
insert into NOTA values (1521, 'examen', 19274, 3, '25-03-2022', 9);
insert into NOTA values (715, 'teza', 95640, 17, '14-09-2022', 2);
insert into NOTA values (1544, 'examen', 18985, 13, '20-01-2022', 5);
insert into NOTA values (938, 'evaluare finala', 91463, 3, '01-05-2022', 10);
insert into NOTA values (990, 'activitate independenta', 27720, 11, '02-08-2022', 1);
insert into NOTA values (1876, 'evaluare', 85575, 18, '03-12-2022', 1);
insert into NOTA values (1268, 'evaluare', 99911, 15, '21-09-2022', 2);
insert into NOTA values (1730, 'evaluare', 97049, 6, '12-11-2022', 9);
insert into NOTA values (1361, 'test', 59573, 4, '29-05-2022', 9);
insert into NOTA values (497, 'activitate independenta', 59825, 17, '12-12-2022', 2);
insert into NOTA values (1870, 'teza', 53992, 9, '25-05-2022', 7);
insert into NOTA values (1656, 'teza', 19274, 14, '20-07-2022', 10);
insert into NOTA values (1024, 'teza', 96162, 14, '23-04-2022', 5);
insert into NOTA values (841, 'teza', 95309, 3, '23-05-2022', 9);
insert into NOTA values (1446, 'evaluare finala', 76297, 11, '01-12-2022', 10);
insert into NOTA values (1004, 'test', 93071, 4, '12-11-2022', 5);
insert into NOTA values (1473, 'test', 90430, 11, '08-04-2022', 6);
insert into NOTA values (767, 'test', 18136, 16, '09-10-2022', 1);
insert into NOTA values (36, 'evaluare finala', 79766, 17, '15-11-2022', 4);
insert into NOTA values (1783, 'evaluare finala', 81003, 2, '23-03-2022', 5);
insert into NOTA values (22, 'test', 37880, 4, '16-06-2022', 4);
insert into NOTA values (1545, 'examen', 79989, 10, '12-03-2022', 10);
insert into NOTA values (201, 'evaluare', 68069, 15, '28-03-2022', 1);
insert into NOTA values (564, 'examen', 18985, 17, '21-02-2022', 10);
insert into NOTA values (576, 'evaluare', 37156, 12, '22-12-2022', 7);
insert into NOTA values (1262, 'examen', 93378, 18, '28-12-2022', 9);
insert into NOTA values (886, 'test', 13931, 1, '01-02-2022', 7);
insert into NOTA values (525, 'teza', 26599, 11, '09-10-2022', 10);
insert into NOTA values (1897, 'activitate independenta', 96162, 13, '15-05-2022', 9);
insert into NOTA values (248, 'evaluare finala', 79766, 12, '22-05-2022', 10);
insert into NOTA values (763, 'evaluare finala', 47168, 16, '29-06-2022', 10);
insert into NOTA values (625, 'test', 12930, 7, '27-07-2022', 3);
insert into NOTA values (718, 'test', 63531, 1, '14-09-2022', 8);
insert into NOTA values (216, 'activitate independenta', 41542, 17, '05-01-2022', 5);
insert into NOTA values (1753, 'evaluare finala', 95857, 15, '08-01-2022', 2);
insert into NOTA values (1817, 'evaluare finala', 13931, 14, '11-10-2022', 5);
insert into NOTA values (1800, 'activitate independenta', 79766, 5, '16-06-2022', 7);
insert into NOTA values (1594, 'evaluare finala', 13170, 10, '09-11-2022', 8);
insert into NOTA values (877, 'evaluare', 68069, 20, '06-10-2022', 10);
insert into NOTA values (801, 'evaluare', 97724, 19, '27-04-2022', 9);
insert into NOTA values (1774, 'activitate independenta', 79989, 6, '21-02-2022', 9);
insert into NOTA values (1834, 'evaluare', 86601, 20, '07-06-2022', 2);
insert into NOTA values (683, 'activitate independenta', 82246, 11, '12-02-2022', 10);
insert into NOTA values (700, 'evaluare finala', 12019, 15, '16-08-2022', 2);
insert into NOTA values (738, 'examen', 37250, 16, '27-06-2022', 2);
insert into NOTA values (641, 'activitate independenta', 44366, 15, '22-03-2022', 5);
insert into NOTA values (1135, 'evaluare finala', 93378, 12, '20-08-2022', 5);
insert into NOTA values (1560, 'evaluare finala', 32131, 2, '18-04-2022', 4);
insert into NOTA values (972, 'activitate independenta', 46399, 1, '09-04-2022', 7);
insert into NOTA values (95, 'teza', 49858, 10, '01-09-2022', 1);
insert into NOTA values (1458, 'evaluare', 23455, 10, '29-10-2022', 10);
insert into NOTA values (1394, 'teza', 39499, 4, '10-03-2022', 6);
insert into NOTA values (37, 'teza', 52700, 17, '09-10-2022', 10);
insert into NOTA values (80, 'teza', 27022, 12, '17-07-2022', 9);
insert into NOTA values (1223, 'examen', 74535, 18, '26-05-2022', 3);
insert into NOTA values (627, 'evaluare finala', 32932, 12, '07-09-2022', 2);
insert into NOTA values (1773, 'evaluare finala', 51581, 9, '27-03-2022', 3);
insert into NOTA values (1305, 'evaluare finala', 30497, 5, '16-12-2022', 6);
insert into NOTA values (593, 'evaluare finala', 79107, 1, '11-12-2022', 8);
insert into NOTA values (1759, 'teza', 59054, 19, '24-03-2022', 5);
insert into NOTA values (1197, 'evaluare', 85575, 20, '01-10-2022', 4);
insert into NOTA values (565, 'teza', 27022, 1, '03-11-2022', 8);
insert into NOTA values (1270, 'evaluare finala', 52379, 9, '02-09-2022', 1);
insert into NOTA values (953, 'activitate independenta', 93748, 20, '04-12-2022', 5);
insert into NOTA values (848, 'test', 79766, 12, '26-02-2022', 8);
insert into NOTA values (179, 'activitate independenta', 30736, 2, '02-02-2022', 10);
insert into NOTA values (758, 'activitate independenta', 33279, 14, '05-01-2022', 4);
insert into NOTA values (1991, 'teza', 76959, 6, '21-05-2022', 8);
insert into NOTA values (228, 'teza', 34008, 7, '05-12-2022', 6);
insert into NOTA values (238, 'examen', 30497, 15, '04-09-2022', 10);
insert into NOTA values (1539, 'activitate independenta', 77632, 3, '16-06-2022', 7);
insert into NOTA values (502, 'teza', 59985, 19, '27-11-2022', 7);
insert into NOTA values (1580, 'evaluare', 91433, 15, '07-01-2022', 2);
insert into NOTA values (1536, 'evaluare', 46821, 16, '01-04-2022', 10);
insert into NOTA values (148, 'examen', 12019, 11, '16-01-2022', 10);
insert into NOTA values (1896, 'activitate independenta', 13170, 6, '02-08-2022', 2);
insert into NOTA values (650, 'evaluare finala', 23455, 18, '10-02-2022', 5);
insert into NOTA values (1120, 'teza', 76959, 15, '22-04-2022', 9);
insert into NOTA values (903, 'evaluare', 34285, 16, '18-07-2022', 8);
insert into NOTA values (1735, 'evaluare', 86601, 12, '26-07-2022', 4);
insert into NOTA values (1251, 'teza', 35283, 12, '27-09-2022', 6);
insert into NOTA values (541, 'evaluare finala', 19274, 9, '23-03-2022', 7);
insert into NOTA values (1434, 'teza', 33799, 12, '27-07-2022', 4);
insert into NOTA values (1448, 'activitate independenta', 19852, 7, '22-01-2022', 6);
insert into NOTA values (1355, 'evaluare finala', 89489, 18, '12-02-2022', 5);
insert into NOTA values (825, 'teza', 54270, 4, '07-10-2022', 10);
insert into NOTA values (1604, 'test', 68054, 16, '19-03-2022', 8);
insert into NOTA values (1387, 'evaluare finala', 34961, 1, '01-11-2022', 5);
insert into NOTA values (1911, 'teza', 60798, 10, '18-11-2022', 5);
insert into NOTA values (1613, 'teza', 71224, 2, '02-02-2022', 9);
insert into NOTA values (1093, 'examen', 11702, 10, '17-12-2022', 3);
insert into NOTA values (1114, 'evaluare', 49349, 13, '08-11-2022', 5);
insert into NOTA values (1895, 'activitate independenta', 13200, 3, '13-08-2022', 3);
insert into NOTA values (1155, 'evaluare', 27720, 6, '03-03-2022', 7);
insert into NOTA values (920, 'activitate independenta', 32651, 13, '22-11-2022', 2);
insert into NOTA values (1048, 'teza', 53388, 12, '19-09-2022', 4);
insert into NOTA values (582, 'evaluare finala', 74966, 15, '14-10-2022', 10);
insert into NOTA values (1885, 'test', 85447, 6, '08-12-2022', 5);
insert into NOTA values (557, 'test', 18177, 17, '03-02-2022', 10);
insert into NOTA values (1376, 'examen', 19852, 20, '03-04-2022', 3);
insert into NOTA values (942, 'evaluare finala', 70793, 16, '23-09-2022', 8);
insert into NOTA values (570, 'evaluare', 77928, 20, '21-01-2022', 7);
insert into NOTA values (762, 'evaluare finala', 24496, 7, '24-09-2022', 8);
insert into NOTA values (1349, 'teza', 32887, 9, '16-12-2022', 9);
insert into NOTA values (480, 'examen', 77928, 11, '26-08-2022', 5);
insert into NOTA values (1538, 'teza', 80557, 9, '17-05-2022', 10);
insert into NOTA values (1695, 'evaluare', 97706, 7, '15-07-2022', 3);
insert into NOTA values (259, 'evaluare finala', 35731, 1, '12-06-2022', 3);
insert into NOTA values (1790, 'test', 41050, 6, '02-07-2022', 10);
insert into NOTA values (1858, 'activitate independenta', 79107, 19, '06-12-2022', 10);
insert into NOTA values (139, 'activitate independenta', 93071, 8, '18-03-2022', 10);
insert into NOTA values (1014, 'evaluare', 59755, 15, '28-03-2022', 10);
insert into NOTA values (1867, 'evaluare finala', 85575, 2, '22-08-2022', 8);
insert into NOTA values (1645, 'activitate independenta', 69298, 11, '27-12-2022', 10);
insert into NOTA values (1841, 'activitate independenta', 81003, 9, '27-11-2022', 4);
insert into NOTA values (1220, 'test', 69298, 14, '09-04-2022', 1);
insert into NOTA values (1589, 'evaluare', 36123, 8, '12-08-2022', 4);
insert into NOTA values (838, 'examen', 95188, 12, '14-06-2022', 3);
insert into NOTA values (791, 'evaluare finala', 86557, 14, '07-03-2022', 5);
insert into NOTA values (1742, 'evaluare', 76959, 15, '08-11-2022', 10);
insert into NOTA values (374, 'examen', 59825, 2, '24-06-2022', 5);
insert into NOTA values (1010, 'examen', 47168, 2, '01-03-2022', 9);
insert into NOTA values (1566, 'examen', 71447, 18, '06-05-2022', 10);
insert into NOTA values (6, 'evaluare finala', 50327, 16, '28-11-2022', 4);
insert into NOTA values (1482, 'evaluare finala', 95857, 10, '21-11-2022', 10);
insert into NOTA values (1659, 'examen', 64514, 5, '04-11-2022', 4);
insert into NOTA values (1693, 'teza', 32932, 1, '16-02-2022', 3);
insert into NOTA values (1177, 'examen', 48303, 19, '18-06-2022', 6);
insert into NOTA values (519, 'evaluare finala', 84498, 17, '01-10-2022', 10);
insert into NOTA values (1760, 'evaluare', 10575, 18, '15-12-2022', 1);
insert into NOTA values (454, 'teza', 42853, 11, '23-10-2022', 10);
insert into NOTA values (1068, 'test', 33279, 11, '17-04-2022', 1);
insert into NOTA values (370, 'evaluare', 76959, 9, '16-02-2022', 10);
insert into NOTA values (803, 'evaluare finala', 79107, 15, '14-02-2022', 5);
insert into NOTA values (339, 'activitate independenta', 74966, 4, '25-04-2022', 2);
insert into NOTA values (674, 'teza', 13931, 10, '06-02-2022', 4);
insert into NOTA values (666, 'evaluare finala', 78084, 15, '25-11-2022', 4);
insert into NOTA values (533, 'teza', 27022, 6, '22-09-2022', 4);
insert into NOTA values (1654, 'activitate independenta', 80557, 13, '09-10-2022', 9);
insert into NOTA values (548, 'examen', 53388, 20, '01-11-2022', 2);
insert into NOTA values (1078, 'activitate independenta', 69929, 9, '10-05-2022', 7);
insert into NOTA values (1954, 'test', 17661, 7, '23-12-2022', 9);
insert into NOTA values (899, 'evaluare finala', 48303, 13, '29-04-2022', 10);
insert into NOTA values (1934, 'test', 27911, 10, '08-12-2022', 9);
insert into NOTA values (251, 'test', 27022, 20, '23-05-2022', 3);
insert into NOTA values (1001, 'evaluare finala', 71224, 14, '19-07-2022', 4);
insert into NOTA values (1179, 'test', 19852, 9, '24-01-2022', 7);
insert into NOTA values (1619, 'evaluare finala', 37250, 11, '21-12-2022', 3);
insert into NOTA values (178, 'test', 76959, 17, '29-05-2022', 1);
insert into NOTA values (1151, 'activitate independenta', 81354, 7, '01-02-2022', 7);
insert into NOTA values (891, 'examen', 54270, 10, '29-01-2022', 1);
insert into NOTA values (812, 'examen', 27022, 2, '22-05-2022', 1);
insert into NOTA values (889, 'activitate independenta', 82246, 15, '24-10-2022', 8);
insert into NOTA values (383, 'examen', 37880, 1, '17-06-2022', 5);
insert into NOTA values (1304, 'teza', 30497, 13, '29-08-2022', 7);
insert into NOTA values (1794, 'examen', 37671, 1, '11-12-2022', 10);
insert into NOTA values (1847, 'teza', 84498, 10, '01-03-2022', 8);
insert into NOTA values (1904, 'evaluare', 95640, 1, '05-03-2022', 6);
insert into NOTA values (1121, 'examen', 81244, 19, '22-07-2022', 5);
insert into NOTA values (1884, 'evaluare', 74966, 3, '27-06-2022', 7);
insert into NOTA values (1201, 'activitate independenta', 99911, 13, '04-12-2022', 9);
insert into NOTA values (943, 'examen', 13931, 18, '20-04-2022', 6);
insert into NOTA values (403, 'evaluare finala', 51581, 8, '14-01-2022', 5);
insert into NOTA values (1365, 'test', 96162, 10, '09-08-2022', 5);
insert into NOTA values (907, 'activitate independenta', 52379, 17, '20-08-2022', 10);
insert into NOTA values (1283, 'examen', 91566, 14, '10-07-2022', 10);
insert into NOTA values (1450, 'examen', 13200, 6, '09-02-2022', 5);
insert into NOTA values (312, 'evaluare', 13170, 7, '07-05-2022', 6);
insert into NOTA values (1989, 'evaluare', 15687, 20, '09-08-2022', 9);
insert into NOTA values (739, 'evaluare finala', 95309, 4, '08-10-2022', 3);
insert into NOTA values (940, 'teza', 46821, 6, '12-12-2022', 3);
insert into NOTA values (367, 'activitate independenta', 54270, 10, '14-08-2022', 2);
insert into NOTA values (442, 'evaluare finala', 37880, 18, '21-12-2022', 1);
insert into NOTA values (859, 'teza', 44366, 4, '25-09-2022', 5);
insert into NOTA values (687, 'activitate independenta', 91433, 14, '12-09-2022', 2);
insert into NOTA values (473, 'activitate independenta', 66790, 12, '20-06-2022', 8);
insert into NOTA values (98, 'evaluare', 84498, 12, '16-11-2022', 8);
insert into NOTA values (347, 'examen', 34285, 7, '24-07-2022', 1);
insert into NOTA values (874, 'teza', 86557, 13, '04-09-2022', 1);
insert into NOTA values (1428, 'test', 78084, 6, '19-04-2022', 10);
insert into NOTA values (1672, 'evaluare finala', 85575, 15, '12-07-2022', 8);
insert into NOTA values (128, 'test', 41050, 6, '21-09-2022', 3);
insert into NOTA values (546, 'teza', 30736, 8, '02-02-2022', 4);
insert into NOTA values (1139, 'examen', 59573, 2, '01-08-2022', 8);
insert into NOTA values (653, 'teza', 86053, 10, '06-07-2022', 3);
insert into NOTA values (789, 'teza', 34763, 8, '26-10-2022', 3);
insert into NOTA values (1436, 'teza', 49349, 17, '10-05-2022', 1);
insert into NOTA values (699, 'activitate independenta', 86557, 10, '26-10-2022', 8);
insert into NOTA values (464, 'evaluare', 51056, 15, '07-11-2022', 1);
insert into NOTA values (432, 'examen', 80663, 1, '02-06-2022', 4);
insert into NOTA values (1065, 'evaluare', 95188, 15, '01-05-2022', 5);
insert into NOTA values (1111, 'test', 79766, 1, '25-04-2022', 5);
insert into NOTA values (711, 'teza', 15687, 4, '03-03-2022', 1);
insert into NOTA values (1892, 'evaluare finala', 76297, 8, '03-06-2022', 6);
insert into NOTA values (1396, 'activitate independenta', 96996, 19, '21-03-2022', 1);
insert into NOTA values (1900, 'evaluare finala', 91463, 7, '23-12-2022', 6);
insert into NOTA values (716, 'evaluare', 94765, 2, '21-04-2022', 2);
insert into NOTA values (1557, 'examen', 84475, 13, '02-10-2022', 3);
insert into NOTA values (1136, 'teza', 79766, 8, '04-01-2022', 10);
insert into NOTA values (1611, 'teza', 91566, 17, '02-11-2022', 10);
insert into NOTA values (428, 'test', 39499, 3, '12-01-2022', 2);
insert into NOTA values (1147, 'examen', 20134, 12, '20-11-2022', 6);
insert into NOTA values (1527, 'activitate independenta', 78878, 4, '08-08-2022', 1);
insert into NOTA values (1838, 'test', 91566, 20, '20-05-2022', 4);
insert into NOTA values (783, 'evaluare', 42980, 16, '09-08-2022', 3);
insert into NOTA values (1311, 'test', 36123, 12, '22-09-2022', 1);
insert into NOTA values (597, 'examen', 27911, 10, '02-01-2022', 4);
insert into NOTA values (264, 'activitate independenta', 81354, 16, '13-04-2022', 7);
insert into NOTA values (223, 'examen', 58540, 2, '01-06-2022', 2);
insert into NOTA values (65, 'evaluare', 42853, 8, '18-11-2022', 1);
insert into NOTA values (1066, 'teza', 95640, 14, '21-02-2022', 8);
insert into NOTA values (144, 'activitate independenta', 86053, 12, '05-05-2022', 9);
insert into NOTA values (1962, 'evaluare finala', 11594, 19, '12-08-2022', 7);
insert into NOTA values (42, 'test', 34763, 12, '01-08-2022', 3);
insert into NOTA values (163, 'teza', 58914, 16, '29-12-2022', 8);
insert into NOTA values (1571, 'activitate independenta', 91463, 7, '16-02-2022', 7);
insert into NOTA values (400, 'evaluare finala', 32932, 13, '27-04-2022', 2);
insert into NOTA values (122, 'test', 20449, 19, '08-07-2022', 3);
insert into NOTA values (1750, 'activitate independenta', 12930, 5, '21-03-2022', 3);
insert into NOTA values (586, 'evaluare finala', 59829, 4, '26-05-2022', 1);
insert into NOTA values (1134, 'evaluare', 13200, 13, '07-06-2022', 2);
insert into NOTA values (698, 'activitate independenta', 32131, 2, '20-03-2022', 5);
insert into NOTA values (966, 'examen', 48418, 3, '23-05-2022', 9);
insert into NOTA values (1680, 'teza', 79766, 1, '13-10-2022', 9);
insert into NOTA values (1369, 'activitate independenta', 76700, 15, '13-04-2022', 7);
insert into NOTA values (1043, 'evaluare', 91433, 6, '10-03-2022', 10);
insert into NOTA values (1378, 'evaluare', 46821, 15, '02-11-2022', 4);
insert into NOTA values (366, 'evaluare finala', 78084, 8, '14-07-2022', 4);
insert into NOTA values (1261, 'test', 42853, 19, '17-12-2022', 3);
insert into NOTA values (1032, 'evaluare finala', 48303, 5, '03-05-2022', 10);
insert into NOTA values (1957, 'test', 59825, 9, '13-06-2022', 7);
insert into NOTA values (1206, 'examen', 79766, 4, '22-04-2022', 9);
insert into NOTA values (1637, 'evaluare finala', 96996, 3, '02-10-2022', 1);
insert into NOTA values (765, 'teza', 34008, 6, '07-11-2022', 2);
insert into NOTA values (59, 'teza', 13200, 13, '06-06-2022', 8);
insert into NOTA values (577, 'evaluare', 60798, 5, '12-09-2022', 5);
insert into NOTA values (172, 'activitate independenta', 56729, 19, '01-09-2022', 3);
insert into NOTA values (1313, 'evaluare', 31898, 6, '26-02-2022', 3);
insert into NOTA values (417, 'evaluare finala', 49349, 8, '19-02-2022', 5);
insert into NOTA values (119, 'evaluare', 41915, 17, '18-09-2022', 4);
insert into NOTA values (620, 'evaluare finala', 56729, 16, '27-01-2022', 8);
insert into NOTA values (1712, 'teza', 13200, 4, '07-04-2022', 10);
insert into NOTA values (1605, 'activitate independenta', 50327, 6, '17-03-2022', 9);
insert into NOTA values (1981, 'examen', 46399, 13, '26-11-2022', 8);
insert into NOTA values (1380, 'test', 60798, 3, '24-07-2022', 5);
insert into NOTA values (710, 'evaluare finala', 18580, 10, '29-03-2022', 2);
insert into NOTA values (1040, 'evaluare', 97724, 20, '17-01-2022', 5);
insert into NOTA values (701, 'evaluare finala', 42980, 5, '29-06-2022', 9);
insert into NOTA values (1779, 'evaluare', 37725, 19, '01-09-2022', 8);
insert into NOTA values (1600, 'evaluare', 93071, 10, '18-08-2022', 5);
insert into NOTA values (880, 'teza', 76700, 14, '10-05-2022', 4);
insert into NOTA values (623, 'evaluare finala', 45754, 12, '07-05-2022', 7);
insert into NOTA values (1983, 'activitate independenta', 92504, 8, '24-12-2022', 7);
insert into NOTA values (530, 'activitate independenta', 81354, 15, '03-06-2022', 9);
insert into NOTA values (1253, 'activitate independenta', 15269, 16, '08-07-2022', 8);
insert into NOTA values (481, 'evaluare', 46399, 14, '17-03-2022', 5);
insert into NOTA values (1007, 'activitate independenta', 53992, 4, '26-12-2022', 2);
insert into NOTA values (751, 'evaluare', 26503, 17, '07-02-2022', 5);
insert into NOTA values (895, 'test', 32887, 2, '25-06-2022', 8);
insert into NOTA values (719, 'activitate independenta', 96162, 17, '26-09-2022', 5);
insert into NOTA values (439, 'test', 74535, 5, '15-02-2022', 9);
insert into NOTA values (102, 'evaluare finala', 27022, 11, '09-07-2022', 9);
insert into NOTA values (1204, 'teza', 12276, 2, '12-12-2022', 9);
insert into NOTA values (1658, 'evaluare', 74535, 17, '11-12-2022', 1);
insert into NOTA values (549, 'examen', 14991, 7, '20-03-2022', 5);
insert into NOTA values (1938, 'test', 95188, 2, '18-06-2022', 8);
insert into NOTA values (1045, 'examen', 41915, 5, '12-10-2022', 9);
insert into NOTA values (575, 'evaluare', 95188, 13, '22-06-2022', 7);
insert into NOTA values (450, 'examen', 20449, 10, '19-05-2022', 3);
insert into NOTA values (1483, 'test', 86601, 20, '22-07-2022', 9);
insert into NOTA values (1421, 'evaluare finala', 26503, 2, '19-01-2022', 1);
insert into NOTA values (1182, 'test', 81354, 19, '07-08-2022', 5);
insert into NOTA values (10, 'examen', 89489, 4, '24-09-2022', 8);
insert into NOTA values (359, 'examen', 35283, 15, '10-11-2022', 1);
insert into NOTA values (1924, 'evaluare finala', 69298, 5, '18-03-2022', 10);
insert into NOTA values (351, 'examen', 52379, 15, '22-07-2022', 7);
insert into NOTA values (358, 'examen', 87780, 19, '06-01-2022', 9);
insert into NOTA values (1612, 'evaluare', 93071, 3, '01-03-2022', 3);
insert into NOTA values (147, 'evaluare', 46821, 11, '01-11-2022', 1);
insert into NOTA values (552, 'teza', 30549, 1, '22-02-2022', 2);
insert into NOTA values (1371, 'evaluare finala', 95640, 17, '22-01-2022', 3);
insert into NOTA values (851, 'teza', 37156, 15, '26-10-2022', 3);
insert into NOTA values (837, 'examen', 67084, 14, '10-07-2022', 7);
insert into NOTA values (1420, 'test', 34008, 11, '23-07-2022', 2);
insert into NOTA values (299, 'examen', 91433, 3, '02-01-2022', 9);
insert into NOTA values (1673, 'test', 33279, 9, '11-09-2022', 5);
insert into NOTA values (1581, 'examen', 58914, 3, '21-09-2022', 4);
insert into NOTA values (132, 'activitate independenta', 42853, 9, '03-12-2022', 1);
insert into NOTA values (957, 'evaluare finala', 58540, 6, '24-10-2022', 5);
insert into NOTA values (1910, 'evaluare finala', 26599, 13, '01-07-2022', 7);
insert into NOTA values (177, 'evaluare finala', 61371, 12, '09-06-2022', 9);
insert into NOTA values (680, 'teza', 30497, 18, '18-05-2022', 1);
insert into NOTA values (875, 'test', 41050, 9, '24-10-2022', 1);
insert into NOTA values (1085, 'evaluare', 77632, 3, '23-08-2022', 7);
insert into NOTA values (76, 'evaluare finala', 13200, 2, '04-11-2022', 9);
insert into NOTA values (1115, 'examen', 12276, 16, '10-09-2022', 9);
insert into NOTA values (961, 'evaluare finala', 74966, 13, '17-06-2022', 5);
insert into NOTA values (611, 'examen', 66790, 1, '29-07-2022', 6);
insert into NOTA values (1184, 'examen', 26989, 13, '21-02-2022', 9);
insert into NOTA values (1833, 'test', 64514, 2, '16-05-2022', 8);
insert into NOTA values (1016, 'teza', 59054, 4, '21-12-2022', 4);
insert into NOTA values (1843, 'examen', 35283, 2, '07-08-2022', 3);
insert into NOTA values (253, 'activitate independenta', 68054, 10, '20-04-2022', 4);
insert into NOTA values (1793, 'activitate independenta', 76959, 18, '25-09-2022', 3);
insert into NOTA values (1883, 'evaluare', 37880, 2, '19-02-2022', 2);
insert into NOTA values (954, 'activitate independenta', 87892, 15, '18-05-2022', 5);
insert into NOTA values (4, 'evaluare', 34285, 17, '20-06-2022', 8);
insert into NOTA values (175, 'examen', 99911, 8, '28-04-2022', 5);
insert into NOTA values (1442, 'evaluare finala', 50327, 15, '10-06-2022', 8);
insert into NOTA values (1088, 'teza', 13931, 6, '20-04-2022', 6);
insert into NOTA values (1170, 'evaluare', 96162, 16, '18-02-2022', 10);
insert into NOTA values (1696, 'examen', 81244, 7, '04-01-2022', 5);
insert into NOTA values (587, 'activitate independenta', 37880, 8, '22-05-2022', 2);
insert into NOTA values (1491, 'teza', 59755, 13, '03-12-2022', 10);
insert into NOTA values (988, 'evaluare', 33799, 4, '03-03-2022', 1);
insert into NOTA values (176, 'teza', 11702, 5, '24-08-2022', 5);
insert into NOTA values (858, 'activitate independenta', 65045, 5, '07-11-2022', 7);
insert into NOTA values (1423, 'test', 59054, 9, '15-01-2022', 5);
insert into NOTA values (640, 'evaluare finala', 41915, 3, '28-07-2022', 3);
insert into NOTA values (58, 'teza', 44638, 14, '25-12-2022', 7);
insert into NOTA values (1640, 'teza', 76959, 8, '08-09-2022', 8);
insert into NOTA values (585, 'activitate independenta', 65478, 11, '18-06-2022', 1);
insert into NOTA values (842, 'teza', 71447, 3, '19-05-2022', 8);
insert into NOTA values (1400, 'teza', 59985, 6, '25-08-2022', 4);
insert into NOTA values (1881, 'test', 93071, 20, '14-07-2022', 6);
insert into NOTA values (324, 'teza', 79308, 3, '15-09-2022', 7);
insert into NOTA values (1664, 'test', 69300, 8, '11-11-2022', 2);
insert into NOTA values (806, 'test', 61371, 15, '05-05-2022', 10);
insert into NOTA values (191, 'activitate independenta', 25275, 19, '23-04-2022', 10);
insert into NOTA values (1798, 'evaluare finala', 10575, 14, '22-12-2022', 4);
insert into NOTA values (1256, 'activitate independenta', 18177, 4, '12-06-2022', 5);
insert into NOTA values (1130, 'activitate independenta', 96342, 20, '27-11-2022', 1);
insert into NOTA values (906, 'teza', 37156, 1, '25-09-2022', 7);
insert into NOTA values (921, 'activitate independenta', 68716, 17, '01-07-2022', 1);
insert into NOTA values (733, 'examen', 37671, 7, '21-02-2022', 9);
insert into NOTA values (1252, 'evaluare finala', 42980, 20, '19-03-2022', 10);
insert into NOTA values (507, 'activitate independenta', 80557, 14, '08-11-2022', 5);
insert into NOTA values (1743, 'test', 65744, 6, '26-02-2022', 9);
insert into NOTA values (19, 'examen', 51581, 18, '11-07-2022', 1);
insert into NOTA values (1092, 'test', 51581, 5, '21-12-2022', 5);
insert into NOTA values (1978, 'examen', 59829, 3, '04-02-2022', 2);
insert into NOTA values (771, 'teza', 37156, 13, '10-08-2022', 10);
insert into NOTA values (375, 'teza', 27911, 16, '18-12-2022', 7);
insert into NOTA values (229, 'activitate independenta', 77632, 15, '04-09-2022', 8);
insert into NOTA values (1995, 'test', 49349, 1, '23-12-2022', 4);
insert into NOTA values (1942, 'evaluare', 11702, 7, '22-04-2022', 8);
insert into NOTA values (1948, 'evaluare', 49349, 5, '17-03-2022', 5);
insert into NOTA values (1703, 'activitate independenta', 54270, 18, '18-07-2022', 3);
insert into NOTA values (755, 'test', 32129, 10, '10-08-2022', 10);
insert into NOTA values (1599, 'evaluare', 24496, 6, '25-06-2022', 1);
insert into NOTA values (667, 'evaluare finala', 13170, 9, '05-03-2022', 5);
insert into NOTA values (142, 'teza', 59054, 17, '13-06-2022', 5);
insert into NOTA values (476, 'examen', 51581, 18, '21-11-2022', 10);
insert into NOTA values (995, 'evaluare finala', 37250, 4, '15-08-2022', 4);
insert into NOTA values (543, 'evaluare', 12930, 3, '21-06-2022', 4);
insert into NOTA values (1028, 'test', 70839, 19, '21-12-2022', 5);
insert into NOTA values (1217, 'examen', 18177, 16, '03-11-2022', 5);
insert into NOTA values (1663, 'teza', 81003, 15, '24-06-2022', 1);
insert into NOTA values (722, 'activitate independenta', 84475, 4, '21-03-2022', 8);
insert into NOTA values (1532, 'evaluare finala', 97724, 17, '14-08-2022', 4);
insert into NOTA values (853, 'evaluare', 27827, 20, '10-09-2022', 10);
insert into NOTA values (1499, 'activitate independenta', 34763, 9, '26-08-2022', 4);
insert into NOTA values (1468, 'test', 11594, 1, '02-04-2022', 10);
insert into NOTA values (1549, 'activitate independenta', 66790, 19, '08-12-2022', 2);
insert into NOTA values (388, 'examen', 96342, 20, '14-01-2022', 10);
insert into NOTA values (103, 'teza', 49858, 10, '09-07-2022', 7);
insert into NOTA values (1342, 'activitate independenta', 59985, 13, '12-09-2022', 7);
insert into NOTA values (485, 'evaluare finala', 11702, 5, '27-11-2022', 6);
insert into NOTA values (1336, 'examen', 33279, 12, '17-08-2022', 4);
insert into NOTA values (1386, 'evaluare', 85447, 8, '27-05-2022', 10);
insert into NOTA values (1462, 'evaluare', 78084, 20, '01-10-2022', 8);
insert into NOTA values (1967, 'examen', 41056, 19, '25-09-2022', 6);
insert into NOTA values (1970, 'examen', 50327, 8, '28-05-2022', 5);
insert into NOTA values (779, 'test', 95309, 18, '01-11-2022', 8);
insert into NOTA values (1862, 'evaluare finala', 68054, 13, '01-03-2022', 9);
insert into NOTA values (1891, 'evaluare finala', 70793, 13, '12-10-2022', 3);
insert into NOTA values (977, 'evaluare finala', 24496, 6, '07-11-2022', 3);
insert into NOTA values (1728, 'evaluare', 80557, 4, '22-09-2022', 2);
insert into NOTA values (1786, 'evaluare', 77928, 18, '22-07-2022', 4);
insert into NOTA values (85, 'evaluare finala', 97049, 16, '04-10-2022', 4);
insert into NOTA values (1390, 'examen', 86601, 9, '14-11-2022', 8);
insert into NOTA values (707, 'examen', 33799, 9, '14-07-2022', 6);
insert into NOTA values (1622, 'test', 66790, 8, '29-05-2022', 9);
insert into NOTA values (1852, 'evaluare finala', 18985, 6, '27-05-2022', 9);
insert into NOTA values (1316, 'test', 91463, 7, '09-10-2022', 4);
insert into NOTA values (1905, 'teza', 26503, 2, '17-12-2022', 7);
insert into NOTA values (682, 'evaluare finala', 80663, 16, '07-07-2022', 1);
insert into NOTA values (326, 'evaluare', 41050, 7, '13-09-2022', 3);
insert into NOTA values (1037, 'test', 59321, 12, '11-05-2022', 4);
insert into NOTA values (1038, 'evaluare finala', 71886, 1, '02-10-2022', 3);
insert into NOTA values (993, 'test', 27911, 9, '17-02-2022', 7);
insert into NOTA values (40, 'evaluare finala', 34961, 11, '05-10-2022', 3);
insert into NOTA values (1307, 'evaluare finala', 71224, 1, '27-04-2022', 4);
insert into NOTA values (932, 'evaluare', 27022, 1, '05-04-2022', 10);
insert into NOTA values (1023, 'activitate independenta', 95188, 6, '01-06-2022', 6);
insert into NOTA values (1828, 'examen', 69929, 8, '21-02-2022', 1);
insert into NOTA values (407, 'test', 81244, 19, '28-04-2022', 6);
insert into NOTA values (1590, 'activitate independenta', 37671, 10, '21-05-2022', 3);
insert into NOTA values (1542, 'examen', 37725, 2, '01-03-2022', 4);
insert into NOTA values (782, 'examen', 30730, 13, '03-11-2022', 5);
insert into NOTA values (411, 'evaluare', 17661, 1, '19-04-2022', 4);
insert into NOTA values (1077, 'teza', 59755, 12, '01-11-2022', 10);
insert into NOTA values (1091, 'examen', 13170, 14, '02-01-2022', 7);
insert into NOTA values (735, 'evaluare finala', 76700, 20, '29-04-2022', 9);
insert into NOTA values (1000, 'test', 52379, 12, '10-09-2022', 10);
insert into NOTA values (1492, 'evaluare', 54270, 9, '08-07-2022', 9);
insert into NOTA values (1801, 'evaluare finala', 19852, 10, '29-09-2022', 5);
insert into NOTA values (1898, 'examen', 53992, 20, '24-02-2022', 5);
insert into NOTA values (729, 'evaluare finala', 71886, 3, '23-06-2022', 6);
insert into NOTA values (1070, 'test', 39499, 13, '28-02-2022', 3);
insert into NOTA values (770, 'evaluare finala', 12930, 11, '09-02-2022', 3);
insert into NOTA values (1508, 'test', 19852, 4, '08-10-2022', 6);
insert into NOTA values (194, 'evaluare finala', 59755, 5, '20-10-2022', 9);
insert into NOTA values (1857, 'evaluare finala', 44366, 6, '09-09-2022', 6);
insert into NOTA values (769, 'examen', 79107, 12, '27-12-2022', 8);
insert into NOTA values (1945, 'examen', 93378, 8, '14-07-2022', 9);
insert into NOTA values (285, 'activitate independenta', 58035, 3, '21-09-2022', 7);
insert into NOTA values (151, 'teza', 86601, 9, '08-06-2022', 3);
insert into NOTA values (96, 'test', 65478, 10, '15-12-2022', 6);
insert into NOTA values (9, 'examen', 92504, 18, '02-06-2022', 9);
insert into NOTA values (1209, 'activitate independenta', 76700, 4, '17-05-2022', 6);
insert into NOTA values (1367, 'teza', 37250, 11, '01-09-2022', 1);
insert into NOTA values (925, 'test', 54270, 12, '27-10-2022', 2);
insert into NOTA values (28, 'examen', 26989, 18, '28-12-2022', 4);
insert into NOTA values (1290, 'examen', 30730, 3, '27-03-2022', 2);
insert into NOTA values (1683, 'evaluare finala', 68054, 9, '25-10-2022', 5);
insert into NOTA values (231, 'evaluare', 23455, 7, '05-09-2022', 1);
insert into NOTA values (140, 'activitate independenta', 71170, 15, '19-10-2022', 8);
insert into NOTA values (1681, 'test', 97724, 2, '23-11-2022', 6);
insert into NOTA values (1476, 'evaluare', 37880, 19, '28-05-2022', 10);
insert into NOTA values (471, 'activitate independenta', 11594, 14, '11-08-2022', 9);
insert into NOTA values (368, 'teza', 12019, 15, '16-06-2022', 1);
insert into NOTA values (1972, 'evaluare', 68069, 15, '25-11-2022', 8);
insert into NOTA values (860, 'activitate independenta', 71886, 10, '20-02-2022', 4);
insert into NOTA values (534, 'activitate independenta', 33279, 16, '07-02-2022', 6);
insert into NOTA values (742, 'evaluare', 82246, 8, '17-02-2022', 1);
insert into NOTA values (346, 'examen', 39499, 7, '08-03-2022', 10);
insert into NOTA values (1407, 'examen', 68054, 1, '03-04-2022', 5);
insert into NOTA values (595, 'test', 13200, 13, '22-08-2022', 5);
insert into NOTA values (882, 'examen', 70793, 2, '16-07-2022', 5);
insert into NOTA values (1411, 'evaluare', 99911, 6, '13-12-2022', 3);
insert into NOTA values (1469, 'test', 70839, 9, '04-07-2022', 5);
insert into NOTA values (475, 'evaluare finala', 77632, 2, '20-08-2022', 4);
insert into NOTA values (449, 'evaluare', 91566, 16, '05-12-2022', 4);
insert into NOTA values (1195, 'evaluare', 19274, 20, '01-11-2022', 1);
insert into NOTA values (691, 'test', 14991, 20, '17-11-2022', 5);
insert into NOTA values (1918, 'examen', 91433, 18, '01-07-2022', 8);
insert into NOTA values (1782, 'evaluare', 12930, 15, '28-11-2022', 8);
insert into NOTA values (606, 'evaluare finala', 59054, 5, '25-09-2022', 6);
insert into NOTA values (197, 'examen', 77928, 3, '26-04-2022', 7);
insert into NOTA values (441, 'test', 69300, 19, '11-08-2022', 4);
