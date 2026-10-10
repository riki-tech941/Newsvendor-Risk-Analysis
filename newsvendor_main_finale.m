% Impostiamo il seed per replicabilità
rng(88);

% Setting parametri
mu= 100;
p= 100;
r_reale= 10;

sigma= [10,20,30];
N= 1000;
m_values= round(linspace(5,30,10)); 

% Scenari di costi per valutare la dipendenza dal margine di guadagno
costi_c= [50,70,90];         % Margine alto, medio e basso
num_scenari= length(costi_c);

% Inizializza un cell array per raccogliere tutti gli output
tutti_risultati= cell(1, num_scenari);

%% Simulazioni
for i= 1:num_scenari
    
    c= costi_c(i);
    fprintf('Simulazione %d/%d: costo c = %d (Margine = %d)\n', i, num_scenari, c, p-c);
    
    r_stimato_valori= linspace(0,c/2,10);
    
    tutti_risultati{i}= newsvendor_sim(mu, p, c, r_reale, sigma, N, m_values, r_stimato_valori);
end

fprintf('Simulazioni completate. Generazione grafici...\n');


%% IC plots (non necessario)
% plot_IC(tutti_risultati{1});
% saveas(gcf, fullfile(fileparts(mfilename('fullpath')), 'IC_stime_media_e_volatilita.png'));

%% Efficiency Heatmaps
plot_efficiency_heatmap(tutti_risultati{1}, 2, 1);
saveas(gcf, fullfile(fileparts(mfilename('fullpath')), 'heatmap_efficienza_margine_alto_c50.png'));
plot_efficiency_heatmap(tutti_risultati{2}, 2, 2);
saveas(gcf, fullfile(fileparts(mfilename('fullpath')), 'heatmap_efficienza_margine_medio_c70.png'));
plot_efficiency_heatmap(tutti_risultati{3}, 2, 3);
saveas(gcf, fullfile(fileparts(mfilename('fullpath')), 'heatmap_efficienza_margine_basso_c90.png'));

%% Quantity Plot
% Vediamo come varia la quantità ordinata al variare del costo e del valore di rivendita stimato
figure('Name', 'Impatto di costi e stime sulla Quantità Ordinata', 'Position', [200,200,800,500]);
hold on; grid on;

% Colori RGB per le tre linee (Verde per margine alto, Arancione per medio, Rosso per basso)
colori_linee= [0.4660 0.6740 0.1880; 0.8500 0.3250 0.0980; 0.6350 0.0780 0.1840]; 

for i= 1:num_scenari
    res= tutti_risultati{i};
    c_val= res.params.c;
        
    % Estraggo tutti i valori di q per sigma = 30 (massima volatilità)
    q= res.q(:,:,:,length(sigma));

    % Faccio una media prima sui campioni e poi sugli m (media della media)
    q_medio= squeeze(mean(mean(q, 1),3));

    % Creo asse X normalizzato (da 0% a 100% del valore possibile di recupero) uso valori % perche il valore di recupero varia con il costo
    x= linspace(0,100,length(res.r_stimato_valori));

    % Plot della linea
    plot(x, q_medio, '-o', 'LineWidth', 2, ...
        'Color', colori_linee(i,:), 'MarkerFaceColor', colori_linee(i,:), ...
        'DisplayName', sprintf('Margine= %d (c=%d)', res.params.p-c_val, c_val));
end

title('Quantità media ordinata al variare di marginalità e stime di recupero (\sigma=30)');
xlabel('Ottimismo sul recupero (r_{stimato} come % del massimo ipotizzato c/2)');
ylabel('Quantità media acquistata (q)');
legend('Location', 'northwest');
hold off;
saveas(gcf, fullfile(fileparts(mfilename('fullpath')), 'quantita_ordinata_vs_margine_e_recupero_stimato.png'));


colori_linee= [0.4660 0.6740 0.1880; 0.8500 0.3250 0.0980; 0.6350 0.0780 0.1840]; % Verde, Arancio, Rosso

%% Grafico costo ignoranza
% Fissato c= 70 (marginalità media -2-) mostra come varia il profitto reale rispetto al profitto onnisciente al variare di m e sigma

figure('Name', 'Costo dell''Ignoranza', 'Position', [100,100,700,450]);
hold on; grid on;

res_base= tutti_risultati{2};

colori_sigma= lines(length(res_base.sigma));

for s_idx= 1:length(res_base.sigma)

    s_val= res_base.sigma(s_idx);
    
    % Profitto per il sigma specifico
    prof_reale= res_base.profitto_reale(:, :, :, s_idx);
    
    % Mediamo su tutte le N simulazioni e su tutte le stime di r
    prof_medio_reale= squeeze(mean(mean(prof_reale, 1), 2)); 
    
    prof_atteso= res_base.profitto_atteso(:,:,:,s_idx);
    prof_medio_atteso= squeeze(mean(mean(prof_atteso, 1), 2)); 
    
    % Profitto onnisciente per questo sigma
    prof_onn= res_base.profitto_onnisciente(s_idx);
    
    % Efficienza Assoluta= Profitto Reale / Profitto Onnisciente
    eff= prof_medio_reale/prof_onn;
    
    plot(res_base.m_values, eff, '-o', 'LineWidth', 2, 'Color', colori_sigma(s_idx,:), 'MarkerFaceColor', colori_sigma(s_idx,:), ...
    'DisplayName', sprintf('\\sigma = %d', s_val));
end

title('Valore dei Dati Storici: Avvicinamento al Profitto Teorico Massimo (Margine=30)');
xlabel('Giorni di storico osservati (m)');
ylabel('Efficienza (Profitto Reale/Onnisciente)');
legend('Location', 'southeast');
ylim([0.8 1.02]);
hold off;
saveas(gcf, fullfile(fileparts(mfilename('fullpath')), 'costo_ignoranza_efficienza_vs_giorni_storico.png'));


%% Grafico Efficienza, analisi della coda (Worst 20%)
figure('Name', 'Costo dell''Ignoranza - Worst 20%', 'Position', [150, 150, 750, 500]);
hold on; grid on; 

res_base= tutti_risultati{2};  % Margine medio (c=70)
colori_sigma= lines(length(res_base.sigma));

% Definisco il taglio (20% peggiore)
N_tot= res_base.params.N;
N_worst= round(N_tot*0.20); 

for s_idx= 1:length(res_base.sigma)

    s_val= res_base.sigma(s_idx);
    
    % Estraiamo il profitto reale per questo sigma
    % Dimensioni: [N_campioni, r_stimati, m_giorni]
    prof_reale= res_base.profitto_reale(:,:,:,s_idx);
    
    % Mediamo prima rispetto alle stime di recupero per isolare l'impatto del campione (m)
    % Usiamo squeeze per ottenere una matrice 2D: [N_campioni x m_giorni]
    prof_reale_m= squeeze(mean(prof_reale, 2)); 
    
    % Ordiniamo la matrice in ordine crescente per ogni colonna (ogni valore di m)
    prof_ordinato= sort(prof_reale_m, 1, 'ascend');
    
    % Selezioniamo solo i primi N_worst campioni (il 20% finale) e mediamo
    prof_peggiori= prof_ordinato(1:N_worst,:);
    prof_peggiore_medio= mean(prof_peggiori, 1);
    
    % Calcoliamo l'Efficienza rispetto al profitto onnisciente
    prof_onn= res_base.profitto_onnisciente(s_idx);
    eff_worst= prof_peggiore_medio/prof_onn;
    
    % Plot
    plot(res_base.m_values, eff_worst, '-o', 'LineWidth', 2, ...
        'Color', colori_sigma(s_idx,:), 'MarkerFaceColor', colori_sigma(s_idx,:), ...
        'DisplayName', sprintf('\\sigma = %d', s_val));
end

% Linea del massimo teorico per riferimento nel grafico
yline(1, '--k', 'Profitto Onnisciente (Massimo Teorico)', ...
    'LineWidth', 1.5, 'LabelHorizontalAlignment', 'left');

title('Efficienza nel 20% dei casi peggiori nel margine medio c=70 (Tail Risk)');
xlabel('Giorni di storico osservati (m)');
ylabel('Efficienza (Profitto Reale / Onnisciente)');
legend('Location', 'southeast');

% Adattamento scala asse Y per migliore rappresentazione dei risultati
ylim([0.4 1.05]); 
hold off;

saveas(gcf, fullfile(fileparts(mfilename('fullpath')), 'costo_ignoranza_worst_20_percent.png'));





%% Heatmap 2D Tasso di Servizio 

% Selezioniamo lo scenario medio: c= 70 (Indice 2), sigma= 20 (Indice 2) 
res_serv= tutti_risultati{2};
idx_s_target= 2; 

% Parametri reali
mu_reale= res_serv.params.mu;
sigma_reale= res_serv.sigma(idx_s_target);

% Estraiamo l'intera matrice delle quantità per questo sigma
% Dimensioni: [N_campioni, r_stimati, m_giorni]
q_mat= res_serv.q(:,:,:,idx_s_target);

% Calcolo del Tasso di Servizio (Service Level)
% normcdf calcola istantaneamente la probabilità che la vera domanda (mu, sigma)
% sia minore o uguale a ciascun q generato nella matrice.
sl_matrice= normcdf(q_mat, mu_reale, sigma_reale);

% Mediamo sui 1000 campioni (lungo la prima dimensione)
% squeeze trasforma il risultato in una matrice 2D con righe= r e colonne= m
tasso_servizio_medio= squeeze(mean(sl_matrice, 1))*100;   % * 100 per ottenere una percentuale

% Plot 2D
figure('Name', 'Heatmap Tasso di Servizio', 'Position', [250, 250, 700, 500]);

% Axis grid
[X_m,Y_r]= meshgrid(res_serv.m_values, res_serv.r_stimato_valori);

% Colori per le Heatmap 
[C_sl, h_sl]= contourf(X_m, Y_r, tasso_servizio_medio, 20, 'LineStyle', 'none');

% Estetica grafico
colormap(turbo); 
cb= colorbar;
ylabel(cb, 'Tasso di Servizio Medio (%)');

title(sprintf('Tasso di Servizio (Prob. di non andare in rottura di stock)\n(c=70, Margine=30, \\sigma=%d)', sigma_reale));
xlabel('Giorni di storico osservati (m)');
ylabel('Valore di recupero stimato (r_{stimato})');

% Aggiungiamo le curve di livello per evidenziare le soglie chiave (es. 50%, 80%, 95%)
hold on;
contour(X_m, Y_r, tasso_servizio_medio, [50 60 70 80 90 95], 'LineColor', [1 1 1], 'ShowText', 'on');
hold off;
saveas(gcf, fullfile(fileparts(mfilename('fullpath')), 'heatmap_tasso_servizio_probabilita_no_stockout.png'));


%% Analisi worst case scenarios

figure('Name', 'Analisi dei Disastri: Confronto Scenari', 'Position', [100, 100, 1000, 450]);

% 1) Scenario Medio (c= 70, sigma= 20, r= c/4)

res_med= tutti_risultati{2};   % Indice 2, c=70
idx_s_med= 2;                  % Indice 2, sigma=20
idx_r_med= 5;                  % Ipotizziamo r= c/4 sia al 5° indice 

% Estrazione ed Efficienza
val_reale_med= squeeze(res_med.profitto_reale(:,idx_r_med,:,idx_s_med));
prof_onn_med= res_med.profitto_onnisciente(idx_s_med);
eff_med= val_reale_med./prof_onn_med;

% Trovo il 5% peggiore
soglia_med= prctile(eff_med(:), 5);
indici_med= find(eff_med<=soglia_med);
[~, idx_m_med]= ind2sub(size(eff_med), indici_med);

eff_peggiori_med= eff_med(indici_med);
giorni_m_med= res_med.m_values(idx_m_med);

% Subplot sx
subplot(1, 2, 1);

% Colore unico (blu) con trasparenza per mostrare efficacemente la densità
scatter(giorni_m_med, eff_peggiori_med, 40, [0 0.4470 0.7410], 'filled', 'MarkerFaceAlpha', 0.4);
yline(0, '--r', 'Profitto = 0', 'LineWidth', 1.5, 'LabelHorizontalAlignment', 'left');

title('Scenario Medio (c=70, \sigma=20)');
xlabel('Giorni di storico osservati (m)');
ylabel('Efficienza sul Profitto Onnisciente');
grid on;


% 2) Scenario Peggiore (c= 90, sigma= 30, r= c/4)

res_wrst= tutti_risultati{3};  % Indice 3, c=90
idx_s_wrst= 3;                 % Indice 3, sigma=30
idx_r_wrst= 5;                 % Ipotizziamo r= c/4 sia al 5° indice

% Estrazione ed Efficienza
val_reale_wrst= squeeze(res_wrst.profitto_reale(:,idx_r_wrst,:,idx_s_wrst));
prof_onn_wrst= res_wrst.profitto_onnisciente(idx_s_wrst);
eff_wrst= val_reale_wrst./prof_onn_wrst;

% Trovo il 5% peggiore
soglia_wrst= prctile(eff_wrst(:),5);
indici_wrst= find(eff_wrst<=soglia_wrst);
[~, idx_m_wrst]= ind2sub(size(eff_wrst), indici_wrst);

eff_peggiori_wrst= eff_wrst(indici_wrst);
giorni_m_wrst= res_wrst.m_values(idx_m_wrst);

% Subplot dx
subplot(1, 2, 2);

% Colore unico (rosso) con trasparenza
scatter(giorni_m_wrst, eff_peggiori_wrst, 40, [0.8500 0.3250 0.0980], 'filled', 'MarkerFaceAlpha', 0.4);
yline(0, '--r', 'Bancarotta (Profitto = 0)', 'LineWidth', 1.5, 'LabelHorizontalAlignment', 'left');

title('Scenario Peggiore (c=90, \sigma=30)');
xlabel('Giorni di storico osservati (m)');
ylabel('Efficienza sul Profitto Onnisciente');
grid on;

sgtitle('Distribuzione del 5% dei casi peggiori (Rischio Estremo)', 'FontWeight', 'bold');

% Sincronizzazione dell'asse Y 
linkaxes(findall(gcf,'type','axes'), 'y');

saveas(gcf, fullfile(fileparts(mfilename('fullpath')), 'worst_case_distribuzione_5pct_scenari_medio_e_peggiore.png'));


%% Analisi Probabilità di Successo (Profitto > 0), solo 5% casi peggiori
figure('Name', 'Probabilità di Profitto Positivo', 'Position', [200, 200, 600, 400]);
hold on; grid on;

res_wrst= tutti_risultati{3};  % Scenario basso margine (c= 90)
idx_s_wrst= 3;                 % sigma= 30
idx_r_wrst= 5;                 % stesso indice usato nel worst case (r= c/4)

% Estraiamo la matrice dei profitti, dimensioni:[N_simulazioni x m_giorni]
prof_reale_mat= squeeze(res_wrst.profitto_reale(:,idx_r_wrst,:,idx_s_wrst));

% Troviamo la soglia del 5% peggiore (come nel precedente grafico)
prof_onn_wrst= res_wrst.profitto_onnisciente(idx_s_wrst);
eff_mat= prof_reale_mat./prof_onn_wrst;

soglia= prctile(eff_mat(:), 5);
maschera= eff_mat<=soglia;      % matrice booleana: true solo per il 5% peggiore

% Per ogni m, probabilità di profitto > 0 SOLO tra i campioni nel 5% peggiore
prob_successo= zeros(1, length(res_wrst.m_values));
for idx_m= 1:length(res_wrst.m_values)
    campioni_peggiori= prof_reale_mat(maschera(:,idx_m), idx_m);
    prob_successo(idx_m)= mean(campioni_peggiori > 0)*100;
end

plot(res_wrst.m_values, prob_successo, '-o', 'LineWidth', 2.5, 'Color', [0.8500 0.3250 0.0980]);
yline(95, '--r', 'Soglia di Sicurezza Desiderata (95%)', 'LineWidth', 1.5, 'LabelHorizontalAlignment', 'right');

title('Probabilità di non fallire nel 5% dei casi peggiori (c=90, \sigma=30)');
xlabel('Giorni di storico osservati (m)');
ylabel('Probabilità di Profitto > 0 (%)');
ylim([0 105]);
hold off;

saveas(gcf, fullfile(fileparts(mfilename('fullpath')), 'probabilita_successo_worst5pct_margine_basso.png'));


%% Costo dell'Ingresso con Informazione Misera (worst 5%)

res_wrst= tutti_risultati{3};     % c= 90
idx_s_wrst= 3;                    % sigma= 30
idx_r_wrst= 5;                    % r= c/4

% Estrazione profitti e Efficienza
prof_reale_mat= squeeze(res_wrst.profitto_reale(:,idx_r_wrst,:,idx_s_wrst));
prof_onn_wrst= res_wrst.profitto_onnisciente(idx_s_wrst);
eff_mat= prof_reale_mat./prof_onn_wrst;

n_tail= floor(0.05*size(prof_reale_mat, 1));   % = 50 se N =1000
nm= length(res_wrst.m_values);

% Inizializzazione 
perdita_attesa= zeros(1, nm);
prob_fallimento= zeros(1, nm);
% var5= zeros(1, nm);

for idx_m= 1:nm
    col= prof_reale_mat(:, idx_m);
    col_sorted= sort(col, 'ascend');          % ordina dal peggiore
    tail= col_sorted(1:n_tail);               % prendi i 50 peggiori

    perdita_attesa(idx_m)= mean(tail);             % negativa
    prob_fallimento(idx_m)= mean(tail < 0)*100;    % conteggio
    % var5(idx_m)= tail(1);                         % il peggiore in assoluto
end

% Costo incrementale rispetto a m =15 (indice più vicino a 15)
[~, idx_m15]= min(abs(m_values-15));

costo_vs_m15= perdita_attesa(idx_m15)-perdita_attesa;  % positivo= perdita extra

% 1) Profitto medio e costo vs m=15 
figure('Name','Costo Ingresso Informazione Misera','Position',[100,100,900,420]);

subplot(1,2,1);
hold on; grid on;
yyaxis left
plot(m_values, perdita_attesa, '-o', 'LineWidth', 2, 'Color', [0.3010 0.7450 0.9330]);
yline(0,'--r','Profitto=0','LineWidth',1.2,'LabelHorizontalAlignment','left');
ylabel('Profitto medio nei peggiori 5% (€)');

yyaxis right
plot(m_values, prob_fallimento, '-s', 'LineWidth', 2, 'Color', [0.8500 0.3250 0.0980]);
yline(5,'--','5% soglia rischio','LineWidth',1,'LabelHorizontalAlignment','right');
ylabel('Prob. fallimento nei peggiori 5% (%)');

title('Profitto e Rischio nei Casi Estremi');
xlabel('Giorni di storico (m)');
legend({'Profitto medio','','Prob. fallimento',''}, 'Location','east');
hold off;

subplot(1,2,2);
hold on; grid on;
bar(m_values, max(0, costo_vs_m15), 'FaceColor', [0.9290 0.6940 0.1250], ...
    'EdgeColor','none', 'FaceAlpha', 0.85);
title(sprintf('Costo Extra vs Entrare con m=%d\n(perdita aggiuntiva attesa nei casi estremi)', m_values(idx_m15)));
xlabel('Giorni di storico (m)');
ylabel('Perdita aggiuntiva attesa (€)');
hold off;

sgtitle('Costo dell''Ingresso con Informazione Misera (c=90, \sigma=30, worst 5%)', ...
    'FontWeight','bold');
    
saveas(gcf, fullfile(fileparts(mfilename('fullpath')), ...
    'costo_ingresso_informazione_misera_worst5pct.png'));


% 2) Distribuzione profitti per m=5, 10, 15
figure('Name','Distribuzione Profitti Casi Estremi','Position',[100,100,800,420]);

m_confronto= [5, 10, 15];
colori_box= [0.6350 0.0780 0.1840;
             0.8500 0.3250 0.0980;
             0.4660 0.6740 0.1880];

dati_box= cell(1,3);
for k= 1:3
    [~, idx_mk]= min(abs(m_values-m_confronto(k))); % m più vicino delle discretizzazione
    
    % Rispetto a m di interesse
    col= prof_reale_mat(:, idx_mk);
    col_sorted= sort(col, 'ascend');
    dati_box{k}= col_sorted(1:n_tail);   % sempre 50 campioni
end

hold on; grid on;
for k= 1:3
    % Violin con istogramma normalizzato 
    edges= linspace(min(dati_box{k}), max(dati_box{k}), 30);
    counts= histcounts(dati_box{k}, edges, 'Normalization', 'pdf');
    bin_w= edges(2)-edges(1);
    counts= counts*bin_w*1.2 ;                % Area integrata a 1.2 per tutti
    centers= (edges(1:end-1)+edges(2:end))/2;

    % Patch sinistra e destra simmetrica
    x_patch= [k-counts, fliplr(k+counts)];
    y_patch= [centers, fliplr(centers)];
    patch(x_patch, y_patch, colori_box(k,:), 'FaceAlpha', 0.5, 'EdgeColor','none');

end

yline(0,'--r','Profitto=0','LineWidth',1.5,'LabelHorizontalAlignment','left');
xticks(1:3);
xticklabels(arrayfun(@(m) sprintf('m = %d', m), m_confronto, 'UniformOutput', false));
ylabel('Profitto realizzato (€)');
title('Distribuzione dei Profitti nel 5% dei Casi Peggiori');
hold off;

saveas(gcf, fullfile(fileparts(mfilename('fullpath')), ...
    'distribuzione_profitti_worst5pct_m5_m10_m15.png'));


%% Impatto variabilità relativa per diversi m
sigma_values= sigma(1):5:sigma(end);
m_confronto= [5, 15, 30];       % poco, medio e tanto storico
colori_m= [0.6350 0.0780 0.1840;
           0.8500 0.3250 0.0980;
           0.4660 0.6740 0.1880];

figure('Name','Impatto Variabilità Relativa','Position',[100,100,750,450]);
hold on; grid on;

for k= 1:length(m_confronto)
    [~, idx_mk]= min(abs(m_values-m_confronto(k)));
    eff_k= zeros(size(sigma_values));

    for i= 1:length(sigma_values)
        res_tmp= newsvendor_sim(mu, p, 70, r_reale, sigma_values(i), ...
                                 1000, m_values, linspace(0,35,10));
                                 
        % Efficienza solo per questo m, media su N e r_stimato
        prof_r= squeeze(res_tmp.profitto_reale(:,:,idx_mk,1));
        prof_o= res_tmp.profitto_onnisciente(1);
        eff_k(i)= mean(prof_r(:))/prof_o;
    end

    plot(sigma_values/mu, eff_k, '-o', 'LineWidth', 2, ...
        'Color', colori_m(k,:), 'MarkerFaceColor', colori_m(k,:), ...
        'DisplayName', sprintf('m = %d giorni', m_confronto(k)));
end

title('Impatto della Volatilità sull''Efficienza per diversi orizzonti storici (c=70)');
xlabel('Coefficiente di variazione \sigma/\mu');
ylabel('Efficienza (Profitto Reale / Onnisciente)');
legend('Location', 'southwest');
hold off;
saveas(gcf, fullfile(fileparts(mfilename('fullpath')), ...
    'impatto_variabilita_relativa_per_m.png'));


%% Diagnostica convergenza MC con intervallo di confidenza
N_values= 10:50:1000;
n_runs= 10;     % n run indipendenti per stimare la varianza
eff_runs= zeros(n_runs, length(N_values));

for r= 1:n_runs
    for i= 1:length(N_values)
        res_tmp= newsvendor_sim(mu, p, 70, r_reale, sigma, ...
                                 N_values(i), m_values, linspace(0,35,10));
        prof_reale= res_tmp.profitto_reale(:,:,:,2);
        prof_onn= res_tmp.profitto_onnisciente(2);
        eff_runs(r,i)= mean(prof_reale(:))/prof_onn;
    end
end

eff_media= mean(eff_runs,1);
eff_std= std(eff_runs,0,1);

figure('Name','Diagnostica Convergenza MC','Position',[100,100,750,420]);
hold on; grid on;

% Banda di confidenza ±1std
fill([N_values, fliplr(N_values)], ...
     [eff_media + eff_std, fliplr(eff_media - eff_std)], ...
     [0.3010 0.7450 0.9330], 'FaceAlpha', 0.25, 'EdgeColor', 'none', ...
     'DisplayName', '\pm 1 std (10 run)');

plot(N_values, eff_media, '-', 'LineWidth', 2, ...
    'Color', [0.0 0.4470 0.7410], 'DisplayName', 'Media (10 run)');

% Linea di convergenza: valore stabile (media degli ultimi 5 punti)
val_conv= mean(eff_media(end-4:end));
yline(val_conv, '--r', sprintf('Valore convergenza = %.4f', val_conv), ...
    'LineWidth', 1.2, 'LabelHorizontalAlignment', 'left');

% Soglia di varianza accettabile — evidenzia dove std scende sotto 0.001
idx_ok= find(eff_std<0.001, 1);
if ~isempty(idx_ok)
    xline(N_values(idx_ok), '--', sprintf('N_{min} \\approx %d', N_values(idx_ok)), ...
        'LineWidth', 1.2, 'Color', [0.4660 0.6740 0.1880], ...
        'LabelVerticalAlignment', 'bottom');
end

title('Diagnostica Convergenza Monte Carlo (c=70, \sigma=20)');
xlabel('Numero simulazioni MC (N)');
ylabel('Efficienza media stimata');
legend('Location', 'southeast');
ylim([val_conv-0.015, val_conv+0.015]);
xlim([N_values(1), N_values(end)]);
hold off;
saveas(gcf, fullfile(fileparts(mfilename('fullpath')), ...
    'diagnostica_convergenza_MC_con_IC.png'));


%%  Contestualizzazione delle cifre utilizzate (range di prezzi)

figure('Name','Contestualizzazione Cifre Assolute','Position', [100, 100, 1000, 480]);

scenari_idx= [2,3];
etichette_sc= {'Margine Medio (c=70)', 'Margine Basso (c=90)'};
idx_s_target= 2;
idx_r_target= 5;

% Definizione colori:
% 1) Rosso [0.8 0.2 0.2] per l'Investimento (Costo)
% 2) Blu   [0.0 0.3 0.5] per il Ricavo Totale 
% 3) Verde [0.1 0.6 0.2] per il Profitto Netto (Guadagno)
colori_bar= [0.80 0.20 0.20;   
             0.00 0.30 0.50;   
             0.10 0.60 0.20];  

for k= 1:2
    res_k= tutti_risultati{scenari_idx(k)};
    c_k= res_k.params.c;
    
    q_mat_k= squeeze(res_k.q(:, idx_r_target, :, idx_s_target));
    q_medio= mean(q_mat_k(:));
    
    prof_mat= squeeze(res_k.profitto_reale(:, idx_r_target, :, idx_s_target));
    profitto_medio= mean(prof_mat(:));
    
    investimento= c_k*q_medio;
    ricavo_medio= profitto_medio+investimento;
    
    valori= [investimento, ricavo_medio, profitto_medio];
    
    subplot(1, 2, k);
    b= bar(valori, 'FaceColor', 'flat');
    
    % Applicazione dei colori personalizzati
    for bi= 1:3
        b.CData(bi,:)= colori_bar(bi,:);
    end
    
    b.EdgeColor= 'none';
    yline(0, '--k', 'LineWidth', 1.2);
    
    set(gca, 'XTickLabel', {'Investimento (Costo)', 'Ricavo Totale', 'Profitto Netto'}, ...
             'XTickLabelRotation', 20);
    
    ylabel('Euro (€)');
    title(etichette_sc{k});
    grid on;
    
    % Aggiunta etichette numeriche sopra le barre
    for bi= 1:3
        ypos= valori(bi);
        offset= sign(ypos)*max(abs(valori))*0.02;
        text(bi, ypos + offset, sprintf('%.0f €', ypos), ...
            'HorizontalAlignment','center','FontSize',9,'FontWeight','bold');
    end
end

sgtitle('Significato delle Cifre: Flussi Economici Medi per Ciclo (\sigma=20)', ...
    'FontWeight','bold');

saveas(gcf, fullfile(fileparts(mfilename('fullpath')), ...
    'contestualizzazione_cifre_assolute_c70_c90.png'));


