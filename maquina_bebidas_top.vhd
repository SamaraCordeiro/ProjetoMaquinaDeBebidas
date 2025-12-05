library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity maquina_bebidas_top is
    Port (
        -- Clock da Placa (50 MHz)
        clock_50        : in  STD_LOGIC;
        
        -- Switches (18 chaves)
        sw              : in  STD_LOGIC_VECTOR(17 downto 0);
        
        -- Botões (4 botões)
        key             : in  STD_LOGIC_VECTOR(3 downto 0);

        -- LEDs vermelhos e verdes
        ledr            : out STD_LOGIC_VECTOR(17 downto 0);
        ledg            : out STD_LOGIC_VECTOR(8 downto 0);
        
        -- Pinos físicos do LCD
        lcd_data        : out STD_LOGIC_VECTOR(7 downto 0);
        lcd_rw          : out STD_LOGIC;
        lcd_en          : out STD_LOGIC;
        lcd_rs          : out STD_LOGIC;
        lcd_on          : out STD_LOGIC;
        lcd_blon        : out STD_LOGIC
    );
end maquina_bebidas_top;

architecture Structural of maquina_bebidas_top is

    -- =========================================================================
    -- 1. COMPONENTES (Controladora, Datapath e LCD)
    -- =========================================================================
    
    component Controladora is
    Port ( 
            clk, rst, ligar, interromper : in STD_LOGIC;
            ficha_detectada, sel_cafe, sel_cha, erro_estoque, pronto_timer : in STD_LOGIC;
            lcd_concluido : in STD_LOGIC; -- O sinal que vem do LCD avisando que terminou

            cont_reset, cont_start, agua_en, cafe_en, cha_en, devolver_tudo, finalizado : out STD_LOGIC;
            troco_normal : out STD_LOGIC;
            seletor_lcd  : out STD_LOGIC_VECTOR(2 downto 0)
        );
    end component;

    -- Componentes do LCD
    component lcd_user_logic is
        PORT(
            clk, lcd_busy, reset_n_in : IN STD_LOGIC;
            seletor_lcd   : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
            lcd_concluido : OUT STD_LOGIC;
            lcd_enable    : BUFFER STD_LOGIC;
            lcd_bus       : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
            lcd_clk, reset_n : OUT STD_LOGIC
        );
    end component;

    component lcd_controller is
        PORT(
            clk, reset_n, lcd_enable : IN STD_LOGIC;
            lcd_bus    : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
            busy       : OUT STD_LOGIC;
            rw, rs, e  : OUT STD_LOGIC;
            lcd_data   : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
            lcd_on, lcd_blon : OUT STD_LOGIC
        );
    end component;

    -- Componentes de Estoque
    component reg_cafe is
        Port ( clk, cafe_set, cafe_en : in std_logic; cafe_atual : out unsigned(1 downto 0); cafe_prox : in unsigned(1 downto 0) );
    end component;

    component reg_cha is
        Port ( clk, cha_set, cha_en : in std_logic; cha_atual : out unsigned(1 downto 0); cha_prox : in unsigned(1 downto 0) );
    end component;
    
    component reg_agua is
        Port ( clk, agua_set, agua_en : in std_logic; agua_atual : out unsigned(1 downto 0); agua_prox : in unsigned(1 downto 0) );
    end component;

    component subtrator_menos_um is
        Port ( qnt_atual : in unsigned(1 downto 0); subtr : in std_logic; qnt_nova : out unsigned(1 downto 0) );
    end component;

    component comp_maior_que_zero is
        Port ( qntd : in std_logic_vector(1 downto 0); saida : out std_logic );
    end component;

    -- Componentes de Tempo e Fichas
    component contador is
        Port ( clk, reset, enable : in std_logic; tempo : out unsigned(4 downto 0) );
    end component;

    component comp_tempo is
        Port ( tempo : in std_logic_vector(4 downto 0); saida : out std_logic );
    end component;

    component comp_fichas is
        Port ( fichas_inseridas : in std_logic_vector(1 downto 0); saida : out std_logic );
    end component;

    component reg_troco is
        Port ( clk, reset : in std_logic; fichas_2 : in unsigned(2 downto 0); troco : out unsigned(2 downto 0) );
    end component;

    -- =========================================================================
    --  2. SINAIS INTERNOS
    -- =========================================================================
    signal clk             : std_logic;
    signal rst             : std_logic;
    signal btn_ligar       : std_logic;
    signal sw_interromper  : std_logic;
    signal sw_sel_cafe     : std_logic;
    signal sw_sel_cha      : std_logic;
    signal sw_fichas       : std_logic_vector(1 downto 0);

    
    -- Sinais de Controle (Saídas da FSM)
    signal s_cont_reset, s_cont_start : std_logic;
    signal s_agua_en, s_cafe_en, s_cha_en : std_logic;
    
    -- Sinais de Status (Entradas da FSM)
    signal s_ficha_detectada : std_logic;
    signal s_erro_estoque    : std_logic;
    signal s_pronto_timer    : std_logic;

    -- Dados de Estoque (Café)
    signal s_cafe_atual, s_cafe_prox : unsigned(1 downto 0);
    signal s_cafe_ok : std_logic;

    -- Dados de Estoque (Chá)
    signal s_cha_atual, s_cha_prox : unsigned(1 downto 0);
    signal s_cha_ok : std_logic;

    -- Dados de Estoque (Água)
    signal s_agua_atual, s_agua_prox : unsigned(1 downto 0);
    signal s_agua_ok : std_logic;

    -- Dados de Tempo
    signal s_tempo_unsigned : unsigned(4 downto 0);
    signal s_tempo_vector   : std_logic_vector(4 downto 0); -- Convertido para o comparador

    -- Dados de Troco
    signal s_calculo_troco : unsigned(2 downto 0);
    signal s_val_troco_out : unsigned(2 downto 0);

    -- Sinais para conexão com o LCD
    signal w_seletor_lcd   : std_logic_vector(2 downto 0);
    signal w_lcd_concluido : std_logic;
    signal w_lcd_enable    : std_logic;
    signal w_lcd_bus       : std_logic_vector(9 downto 0);
    signal w_lcd_busy      : std_logic;
    signal w_reset_n_lcd   : std_logic; -- Reset invertido pro LCD

begin
    -- =========================================================================
    -- 3. INSTANCIAÇÃO E MAPEAMENTO DOS PINOS DA PLACA
    -- =========================================================================
    clk <= clock_50;
    rst <= sw(17);             -- Switch 17 é o Reset Geral

    btn_ligar <= not key(0); -- Como os botões da DE2 são invertidos (0 quando aperta). Colocamos um not p/resolver isso

    sw_interromper <= sw(0);   -- Switch 0 interrompe
    sw_sel_cafe    <= sw(1);   -- Switch 1 para o café
    sw_sel_cha     <= sw(2);   -- Switch 2 para o chá
    sw_fichas      <= sw(16 downto 15); -- Switches 16 e 15 simulam as fichas
    
    -- Reset pro LCD (ele precisa ser 0 pra resetar, então invertemos o rst)
    w_reset_n_lcd <= not sw(17);

    -- =========================================================================
    -- 4. INSTANCIAÇÃO (Ligando os blocos)
    -- =========================================================================

    U_CONTROLADORA: Controladora
    port map (
        clk             => clk,
        rst             => rst,
        ligar           => btn_ligar,
        interromper     => sw_interromper,
        ficha_detectada => s_ficha_detectada,
        sel_cafe        => sw_sel_cafe,
        sel_cha         => sw_sel_cha,
        erro_estoque    => s_erro_estoque,
        pronto_timer    => s_pronto_timer,

        -- Ligando o fio do LCD
        lcd_concluido   => w_lcd_concluido,
        
        cont_reset      => s_cont_reset,
        cont_start      => s_cont_start,
        agua_en         => s_agua_en,
        cafe_en         => s_cafe_en,
        cha_en          => s_cha_en,

        -- Saídas visuais (LEDs da placa)
        troco_normal    => ledg(0), -- Led Verde 0
        devolver_tudo   => ledr(0), -- Led Vermelho 0
        finalizado      => ledg(7), -- Led Verde 7
        seletor_lcd     => w_seletor_lcd
    );

    -- LÓGICA DO LCD (Converte o código da FSM em texto)
    U_LCD_USER: lcd_user_logic
    port map (
        clk           => clk,
        lcd_busy      => w_lcd_busy,
        reset_n_in    => w_reset_n_lcd,
        seletor_lcd   => w_seletor_lcd,
        lcd_concluido => w_lcd_concluido,
        lcd_enable    => w_lcd_enable,
        lcd_bus       => w_lcd_bus,
        lcd_clk       => open,
        reset_n       => open
    );
        
    -- CONTROLADOR DO LCD (Mexe nos pinos físicos da tela)
    U_LCD_DRIVER: lcd_controller
    port map (
        clk        => clk,
        reset_n    => w_reset_n_lcd,
        lcd_enable => w_lcd_enable,
        lcd_bus    => w_lcd_bus,
        busy       => w_lcd_busy,
        
        -- Pinos físicos externos
        rw         => lcd_rw,
        rs         => lcd_rs,
        e          => lcd_en,
        lcd_data   => lcd_data,
        lcd_on     => lcd_on,
        lcd_blon   => lcd_blon
    );
        
    -- -------------------------------------------------------------------------
    -- 5. DATAPATH
    -- -------------------------------------------------------------------------
    -- Bloco para o café
    U_REG_CAFE: reg_cafe
    port map ( clk => clk, cafe_set => rst, cafe_en => s_cafe_en, cafe_atual => s_cafe_atual, cafe_prox => s_cafe_prox );

    U_SUB_CAFE: subtrator_menos_um
    port map ( qnt_atual => s_cafe_atual, subtr => s_cafe_en, qnt_nova => s_cafe_prox );

    U_CHECK_CAFE: comp_maior_que_zero
    port map ( qntd => std_logic_vector(s_cafe_atual), saida => s_cafe_ok );

    -- Bloco para o chá
    U_REG_CHA: reg_cha
    port map ( clk => clk, cha_set => rst, cha_en => s_cha_en, cha_atual => s_cha_atual, cha_prox => s_cha_prox );

    U_SUB_CHA: subtrator_menos_um
    port map ( qnt_atual => s_cha_atual, subtr => s_cha_en, qnt_nova => s_cha_prox );

    U_CHECK_CHA: comp_maior_que_zero
    port map ( qntd => std_logic_vector(s_cha_atual), saida => s_cha_ok );

    -- Bloco para a água
    U_REG_AGUA: reg_agua
    port map ( clk => clk, agua_set => rst, agua_en => s_agua_en, agua_atual => s_agua_atual, agua_prox => s_agua_prox );

    U_SUB_AGUA: subtrator_menos_um
    port map ( qnt_atual => s_agua_atual, subtr => s_agua_en, qnt_nova => s_agua_prox );

    U_CHECK_AGUA: comp_maior_que_zero
    port map ( qntd => std_logic_vector(s_agua_atual), saida => s_agua_ok );

    -- -------------------------------------------------------------------------
    -- BLOCO DE TEMPO
    -- -------------------------------------------------------------------------
    U_CONTADOR: contador
    port map ( clk => clk, reset => s_cont_reset, enable => s_cont_start, tempo => s_tempo_unsigned );

    -- Converte o unsigned do contador para o vector do comparador
    s_tempo_vector <= std_logic_vector(s_tempo_unsigned);

    U_COMP_TEMPO: comp_tempo
    port map ( tempo => s_tempo_vector, saida => s_pronto_timer );

    -- -------------------------------------------------------------------------
    -- BLOCO DE FICHAS E TROCO
    -- -------------------------------------------------------------------------
    U_COMP_FICHAS: comp_fichas
    port map ( fichas_inseridas => sw_fichas, saida => s_ficha_detectada );

    U_REG_TROCO: reg_troco
    port map ( clk => clk, reset => rst, fichas_2 => s_calculo_troco, troco => s_val_troco_out );

    -- =========================================================================
    -- 6. lÓGICA AUXILIAR (Lógica de Conexão e Adaptação)
    -- =========================================================================

    -- Lógica do Troco:
    -- Assume-se que a entrada é de 2 bits. Vamos converter e subtrair.
    -- O 'unsigned' precisa de conversão pois a entrada é std_logic_vector.
    -- Expandi para 3 bits para evitar overflow/underflow na conta, embora a entrada seja pequena.
    s_calculo_troco <= resize(unsigned(sw_fichas), 3) - 2;

    -- Lógica Unificada de Erro de Estoque:
    -- O erro é ativado SE:
    -- (Selecionou Café E Café acabou) OU (Selecionou Chá E Chá acabou) OU (Água acabou)
    -- Nota: 'ok' significa > 0. Então erro é NOT ok.
    s_erro_estoque <= '1' when (sw_sel_cafe = '1' and s_cafe_ok = '0') else
                      '1' when (sw_sel_cha = '1'  and s_cha_ok = '0')  else
                      '1' when (s_agua_ok = '0') else -- Falta de água trava tudo
                      '0';

    -- Debug: mostrando algumas coisas nos LEDs vermelhos extras
    ledr(17) <= rst; -- Ver se o reset tá apertado
    ledr(1)  <= s_cafe_ok; -- Pra conferir se tem café
    ledr(2)  <= s_cha_ok;  -- Pra conferir se tem chá

end Structural;

