function plot_efficiency_heatmap(risultati, idx_s_target, scenario)

m_values= risultati.m_values;
r_vals= risultati.r_stimato_valori;
margine= scenario;

mean_prof_reale= squeeze(mean(risultati.profitto_reale(:,:,:,idx_s_target), 1));
prof_onn= risultati.profitto_onnisciente(idx_s_target);
mean_prof_atteso= squeeze(mean(risultati.profitto_atteso(:,:,:,idx_s_target), 1));

ratio= mean_prof_reale./prof_onn;

% Limiti fissi per miglior confronto visivo tra scenari
cmin= 0.875;
cmax= 1.00;
livelli= linspace(cmin, cmax, 30);          % livelli contourf
livelli_bianchi= linspace(cmin, cmax, 10); % livelli contour bianchi

[X, Y]= meshgrid(m_values, r_vals);

figure;
contourf(X, Y, ratio, livelli, 'LineStyle', 'none');
colormap(turbo);
cb = colorbar;
clim([cmin, cmax]);   % fissa i limiti del colore 
ylabel(cb, 'Profitto Reale / Onnisciente');

title(['Efficienza profitto con variabilità media (sig=20), margine: ', num2str(margine)]);
xlabel('Giorni di storico (m)');
ylabel('Valore di recupero (r_{stimato})');

hold on;
contour(X, Y, ratio, livelli_bianchi, 'LineColor', [1 1 1], 'ShowText', 'on');
hold off;
end