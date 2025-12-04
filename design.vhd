library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Maquina_Bebidas_Top is
    Port (
        clk             : in  STD_LOGIC;
        rst             : in  STD_LOGIC; -- Reset geral do sistema

        -- Entradas do Usuário
        btn_ligar       : in  STD_LOGIC;
        sw_interromper  : in  STD_LOGIC;
        
        -- Entradas de Configuração/Sensores
        sw_fichas       : in  STD_LOGIC_VECTOR(1 downto 0); -- Quantidade de fichas
        sw_sel_cafe     : in  STD_LOGIC;
        sw_sel_cha      : in  STD_LOGIC;

        -- Saídas Visuais
        led_troco       : out STD_LOGIC;
        led_devolver    : out STD_LOGIC;
        led_erro        : out STD_LOGIC;
        led_finalizado  : out STD_LOGIC;
        
        -- Saída de valor (Troco)
        val_troco_out   : out unsigned(2 downto 0);
        
        -- Debug (Opcional: para ver se o estoque está descendo)
        debug_estoque_cafe : out unsigned(1 downto 0)
    );
end Maquina_Bebidas_Top;

architecture Structural of Maquina_Bebidas_Top is

    -- =========================================================================
    -- 1. DECLARAÇÃO DOS COMPONENTES (Copiados dos seus arquivos)
    -- =========================================================================
    
    component Controladora is
        Port ( 
            clk, rst, ligar, interromper : in STD_LOGIC;
            ficha_detectada, sel_cafe, sel_cha, erro_estoque, pronto_timer : in STD_LOGIC;
            cont_reset, cont_start, agua_en, cafe_en, cha_en, troco_normal, devolver_tudo, msg_erro, finalizado : out STD_LOGIC
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
    -- 2. SINAIS INTERNOS (Os fios do circuito)
    -- =========================================================================

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
    signal s_tempo_vector   : std_logic_vector(5 downto 0); -- Convertido para o comparador

    -- Dados de Troco
    signal s_calculo_troco : unsigned(2 downto 0);

begin

    -- =========================================================================
    -- 3. INSTANCIAÇÃO E MAPEAMENTO
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
        erro_estoque    => s_erro_estoque, -- Sinal combinado calculado abaixo
        pronto_timer    => s_pronto_timer,
        cont_reset      => s_cont_reset,
        cont_start      => s_cont_start,
        agua_en         => s_agua_en,
        cafe_en         => s_cafe_en,
        cha_en          => s_cha_en,
        troco_normal    => led_troco,
        devolver_tudo   => led_devolver,
        msg_erro        => led_erro,
        finalizado      => led_finalizado
    );

    -- -------------------------------------------------------------------------
    -- BLOCO DE CAFÉ (Registrador + Subtrator + Verificador)
    -- -------------------------------------------------------------------------
    U_REG_CAFE: reg_cafe
    port map ( clk => clk, cafe_set => rst, cafe_en => s_cafe_en, cafe_atual => s_cafe_atual, cafe_prox => s_cafe_prox );

    U_SUB_CAFE: subtrator_menos_um
    port map ( qnt_atual => s_cafe_atual, subtr => s_cafe_en, qnt_nova => s_cafe_prox );

    U_CHECK_CAFE: comp_maior_que_zero
    port map ( qntd => std_logic_vector(s_cafe_atual), saida => s_cafe_ok );

    -- -------------------------------------------------------------------------
    -- BLOCO DE CHÁ
    -- -------------------------------------------------------------------------
    U_REG_CHA: reg_cha
    port map ( clk => clk, cha_set => rst, cha_en => s_cha_en, cha_atual => s_cha_atual, cha_prox => s_cha_prox );

    U_SUB_CHA: subtrator_menos_um
    port map ( qnt_atual => s_cha_atual, subtr => s_cha_en, qnt_nova => s_cha_prox );

    U_CHECK_CHA: comp_maior_que_zero
    port map ( qntd => std_logic_vector(s_cha_atual), saida => s_cha_ok );

    -- -------------------------------------------------------------------------
    -- BLOCO DE ÁGUA
    -- -------------------------------------------------------------------------
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

    U_COMP_TEMPO: comp_tempo
    port map ( tempo => s_tempo_vector, saida => s_pronto_timer );

    -- -------------------------------------------------------------------------
    -- BLOCO DE FICHAS E TROCO
    -- -------------------------------------------------------------------------
    U_COMP_FICHAS: comp_fichas
    port map ( fichas_inseridas => sw_fichas, saida => s_ficha_detectada );

    U_REG_TROCO: reg_troco
    port map ( clk => clk, reset => rst, fichas_2 => s_calculo_troco, troco => val_troco_out );

    -- =========================================================================
    -- 4. GLUE LOGIC (Lógica de Conexão e Adaptação)
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

    -- Debug
    debug_estoque_cafe <= s_cafe_atual;

end Structural;