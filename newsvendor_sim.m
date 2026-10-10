function risultati= newsvendor_sim(mu, p, c, r_reale, sigma, N, m_values, r_stimato_valori)

%   PARAMETRI
%   mu               : media della domanda 
%   p                : prezzo di vendita   
%   c                : costo di acquisto   
%   r_reale          : valore di recupero reale dalla svendita 
%   sigma            : vettore delle varianze da testare    
%   N                : numero di repliche Monte Carlo        
%   m_values         : vettore dei giorni di storico          
%   r_stimato_valori : vettore dei valori di recupero stimati 

% Loss Function L(z) -Equazione (4)-
L= @(z) normpdf(z)-z.*(1-normcdf(z));
 
% Marginali fissi per la simulazione
cu= p-c;                 %underage
co_reale= c-r_reale;     %overage reale

% Setting dimensioni
nr= length(r_stimato_valori);
nm= length(m_values);
ns= length(sigma);
 
% Pre-allocazione
q= zeros(N, nr, nm, ns);
profitto_atteso= zeros(N, nr, nm, ns);
profitto_reale= zeros(N, nr,nm, ns);      % Il profitto atteso reale

% Profitto onnisciente (che si ha conoscendo tutti i valori reali) 
profitto_onnisciente= zeros(1, ns);

% Stime per gli IC
m_hat_all= zeros(N, nm, ns);
s_hat_all= zeros(N, nm, ns);
 
% Loop su sigma
for idx_s= 1:ns
    s= sigma(idx_s);

    % Calcolo profitto onnisciente
    z_onn= norminv(cu/(cu+co_reale));    % Equazione (3)
    q_onn= mu+s*z_onn;
    profitto_onnisciente(idx_s)= cu*mu-co_reale*(q_onn-mu)-(cu+co_reale)*s*L(z_onn);  % Equazione (6)
 
    % Loop su m
    for idx_m= 1:nm
        m= m_values(idx_m);
        
        % MC samples
        sample= mu+s*randn(N,m);
        
        % Stime
        m_hat= mean(sample,2);
        s_hat= std(sample,0,2); 

        m_hat_all(:, idx_m, idx_s)= m_hat;
        s_hat_all(:, idx_m, idx_s)= s_hat;
 
        co_stimato_vec= max(1e-6, c-r_stimato_valori);   % MAX per evitare valori negativi
        alpha_vec= cu./(cu+co_stimato_vec);
        z_star_vec= norminv(alpha_vec);

        % Dim expansion
        m_hat_mat= repmat(m_hat,1,nr);
        s_hat_mat= repmat(s_hat,1,nr);
        z_mat= repmat(z_star_vec,N,1);

        % Ottimo stimato
        q_star= max(0, m_hat_mat+s_hat_mat.*z_mat);
        q(:,:,idx_m,idx_s)= q_star;

        % Profitto atteso stimato
        co_mat= repmat(co_stimato_vec,N,1);

        profitto_atteso(:,:, idx_m, idx_s)= cu*m_hat_mat-co_mat.*(q_star-m_hat_mat)- ...
        (cu+co_mat).*s_hat_mat.*L(z_mat);
            
        % Profitto atteso reale
        z_real= (q_star-mu)/s;

        profitto_reale(:,:,idx_m, idx_s)= cu*mu- co_reale*(q_star-mu)-...
        (cu+co_reale)*s*L(z_real);    % Equazione (7)
            
    end

end
        

% Raccolta output e metadati di simulazione (.params)

risultati.q                   = q;
risultati.profitto_atteso     = profitto_atteso;
risultati.profitto_reale      = profitto_reale;
risultati.profitto_onnisciente = profitto_onnisciente;
risultati.m_values            = m_values;
risultati.r_stimato_valori    = r_stimato_valori;
risultati.sigma               = sigma;
risultati.params.mu           = mu;
risultati.params.p            = p;
risultati.params.c            = c;
risultati.params.r_reale      = r_reale;
risultati.params.N            = N;
risultati.m_hat               = m_hat_all;
risultati.s_hat               = s_hat_all;


end

 