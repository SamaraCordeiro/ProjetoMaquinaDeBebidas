library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity maquina_bebidas_top is
    Port (
        clock_50        : in  STD_LOGIC;
        sw              : in  STD_LOGIC_VECTOR(17 downto 0);
        key             : in  STD_LOGIC_VECTOR(3 downto 0);
        
        ledr            : out STD_LOGIC_VECTOR(17 downto 0);
        ledg            : out STD_LOGIC_VECTOR(8 downto 0);
        
        hex7, hex6, hex5, hex4 : out STD_LOGIC_VECTOR(6 downto 0);
        hex3, hex2, hex1, hex0 : out STD_LOGIC_VECTOR(6 downto 0);
        
        lcd_data        : out STD_LOGIC_VECTOR(7 downto 0);
        lcd_rw, lcd_en, lcd_rs, lcd_on, lcd_blon : out STD_LOGIC
    );
end maquina_bebidas_top;

architecture Structural of maquina_bebidas_top is

    -- COMPONENTES (Controladora atualizada)
    component Controladora is
    Port ( 
            clk, rst, ligar, interromper : in STD_LOGIC;
            ficha_detectada, sel_cafe, sel_cha, erro_estoque, pronto_timer : in STD_LOGIC;
            lcd_concluido : in STD_LOGIC; 
            cont_reset, cont_start, agua_en, cafe_en, cha_en, devolver_tudo, finalizado : out STD_LOGIC;
            troco_normal : out STD_LOGIC;
            sistema_ativo : out STD_LOGIC; -- NOVO
            seletor_lcd  : out STD_LOGIC_VECTOR(2 downto 0)
        );
    end component;
    
    component lcd_user_logic is
        PORT( clk, lcd_busy, reset_n_in : IN STD_LOGIC; seletor_lcd : IN STD_LOGIC_VECTOR(2 DOWNTO 0); lcd_concluido : OUT STD_LOGIC; lcd_enable : BUFFER STD_LOGIC; lcd_bus : OUT STD_LOGIC_VECTOR(9 DOWNTO 0); lcd_clk, reset_n : OUT STD_LOGIC );
    end component;
    component lcd_controller is
        PORT( clk, reset_n, lcd_enable : IN STD_LOGIC; lcd_bus : IN STD_LOGIC_VECTOR(9 DOWNTO 0); busy : OUT STD_LOGIC; rw, rs, e : OUT STD_LOGIC; lcd_data : OUT STD_LOGIC_VECTOR(7 DOWNTO 0); lcd_on, lcd_blon : OUT STD_LOGIC );
    end component;
    component reg_cafe is Port ( clk, cafe_set, cafe_en : in std_logic; cafe_atual : out unsigned(1 downto 0); cafe_prox : in unsigned(1 downto 0) ); end component;
    component reg_cha is Port ( clk, cha_set, cha_en : in std_logic; cha_atual : out unsigned(1 downto 0); cha_prox : in unsigned(1 downto 0) ); end component;
    component reg_agua is Port ( clk, agua_set, agua_en : in std_logic; agua_atual : out unsigned(1 downto 0); agua_prox : in unsigned(1 downto 0) ); end component;
    component subtrator_menos_um is Port ( qnt_atual : in unsigned(1 downto 0); subtr : in std_logic; qnt_nova : out unsigned(1 downto 0) ); end component;
    component comp_maior_que_zero is Port ( qntd : in std_logic_vector(1 downto 0); saida : out std_logic ); end component;
    component contador is Port ( clk, reset, enable : in std_logic; tempo : out unsigned(4 downto 0) ); end component;
    component comp_tempo is Port ( tempo : in std_logic_vector(4 downto 0); saida : out std_logic ); end component;
    component comp_fichas is Port ( fichas_inseridas : in std_logic_vector(1 downto 0); saida : out std_logic ); end component;
    component reg_troco is Port ( clk, reset : in std_logic; fichas_2 : in unsigned(2 downto 0); troco : out unsigned(2 downto 0) ); end component;

    -- SINAIS
    signal clk_lento : std_logic;
    signal contador_clk : integer range 0 to 2500000;
    signal rst, btn_ligar, sw_interromper, sw_sel_cafe, sw_sel_cha : std_logic;
    signal sw_fichas : std_logic_vector(1 downto 0);
    signal s_cont_reset, s_cont_start, s_agua_en, s_cafe_en, s_cha_en : std_logic;
    signal s_ficha_detectada, s_erro_estoque, s_pronto_timer : std_logic;
    signal s_cafe_atual, s_cafe_prox, s_cha_atual, s_cha_prox, s_agua_atual, s_agua_prox : unsigned(1 downto 0);
    signal s_cafe_ok, s_cha_ok, s_agua_ok : std_logic;
    signal s_tempo_unsigned : unsigned(4 downto 0);
    signal s_tempo_vector : std_logic_vector(4 downto 0);
    signal s_calculo_troco, s_val_troco_out : unsigned(2 downto 0);
    
    signal s_fichas_registradas : std_logic_vector(1 downto 0) := "00";
    signal s_finalizado_interno : std_logic;
    signal s_status_hex : std_logic_vector(6 downto 0);
    signal s_troco_bits : std_logic_vector(2 downto 0);
    signal w_seletor_lcd_3 : std_logic_vector(2 downto 0);
    signal s_devolver_tudo : std_logic;
    signal s_sistema_ativo : std_logic; -- Novo sinal

    signal sw_refill_cafe, sw_refill_cha, sw_refill_agua : std_logic;

    -- LCD Dummy
    signal w_lcd_concluido, w_lcd_enable, w_lcd_busy, w_reset_n_lcd : std_logic; 
    signal w_lcd_bus : std_logic_vector(9 downto 0);

begin
    -- DIVISOR DE CLOCK
    process(clock_50) begin
        if rising_edge(clock_50) then
            if contador_clk = 2500000 then clk_lento <= not clk_lento; contador_clk <= 0;
            else contador_clk <= contador_clk + 1; end if;
        end if;
    end process;

    -- MEMÓRIA DE DINHEIRO
    process(clock_50, rst, s_finalizado_interno)
    begin
        if s_finalizado_interno = '1' or s_devolver_tudo = '1' then
            s_fichas_registradas <= "00";
        elsif rising_edge(clock_50) then
            if unsigned(sw_fichas) > unsigned(s_fichas_registradas) then
                s_fichas_registradas <= sw_fichas;
            end if;
        end if;
    end process;

    -- Mapeamento
    rst <= '0'; btn_ligar <= not key(0); sw_interromper <= sw(0);
    sw_sel_cafe <= sw(1); sw_sel_cha <= sw(2); sw_fichas <= sw(16 downto 15);
    sw_refill_cafe <= sw(4); sw_refill_cha  <= sw(5); sw_refill_agua <= sw(6);

    -- CONTROLADORA
    U_CONTROLADORA: Controladora port map (
        clk => clk_lento, rst => '0', ligar => btn_ligar, interromper => sw_interromper, 
        ficha_detectada => s_ficha_detectada, 
        sel_cafe => sw_sel_cafe, sel_cha => sw_sel_cha, erro_estoque => s_erro_estoque, pronto_timer => s_pronto_timer,
        lcd_concluido => '1', 
        cont_reset => s_cont_reset, cont_start => s_cont_start,
        agua_en => s_agua_en, cafe_en => s_cafe_en, cha_en => s_cha_en, 
        devolver_tudo => s_devolver_tudo,
        troco_normal => ledg(0), 
        sistema_ativo => s_sistema_ativo, -- Conectando novo sinal
        finalizado => s_finalizado_interno, 
        seletor_lcd => w_seletor_lcd_3
    );
    ledg(7) <= s_finalizado_interno;
    ledr(0) <= s_devolver_tudo;

    -- LCD OFF
    lcd_on <= '0'; lcd_blon <= '0'; lcd_rw <= '0'; lcd_en <= '0'; lcd_rs <= '0'; lcd_data <= (others => '0');

    -- DATAPATH
    U_REG_CAFE: reg_cafe port map ( clk => clk_lento, cafe_set => sw_refill_cafe, cafe_en => s_cafe_en, cafe_atual => s_cafe_atual, cafe_prox => s_cafe_prox );
    U_SUB_CAFE: subtrator_menos_um port map ( qnt_atual => s_cafe_atual, subtr => s_cafe_en, qnt_nova => s_cafe_prox );
    U_CHECK_CAFE: comp_maior_que_zero port map ( qntd => std_logic_vector(s_cafe_atual), saida => s_cafe_ok );

    U_REG_CHA: reg_cha port map ( clk => clk_lento, cha_set => sw_refill_cha, cha_en => s_cha_en, cha_atual => s_cha_atual, cha_prox => s_cha_prox );
    U_SUB_CHA: subtrator_menos_um port map ( qnt_atual => s_cha_atual, subtr => s_cha_en, qnt_nova => s_cha_prox );
    U_CHECK_CHA: comp_maior_que_zero port map ( qntd => std_logic_vector(s_cha_atual), saida => s_cha_ok );

    U_REG_AGUA: reg_agua port map ( clk => clk_lento, agua_set => sw_refill_agua, agua_en => s_agua_en, agua_atual => s_agua_atual, agua_prox => s_agua_prox );
    U_SUB_AGUA: subtrator_menos_um port map ( qnt_atual => s_agua_atual, subtr => s_agua_en, qnt_nova => s_agua_prox );
    U_CHECK_AGUA: comp_maior_que_zero port map ( qntd => std_logic_vector(s_agua_atual), saida => s_agua_ok );

    U_CONTADOR: contador port map ( clk => clk_lento, reset => s_cont_reset, enable => s_cont_start, tempo => s_tempo_unsigned );
    s_tempo_vector <= std_logic_vector(s_tempo_unsigned);
    U_COMP_TEMPO: comp_tempo port map ( tempo => s_tempo_vector, saida => s_pronto_timer );

    U_COMP_FICHAS: comp_fichas port map ( fichas_inseridas => s_fichas_registradas, saida => s_ficha_detectada );
    s_calculo_troco <= resize(unsigned(s_fichas_registradas), 3) - 2;
    U_REG_TROCO: reg_troco port map ( clk => clk_lento, reset => '0', fichas_2 => s_calculo_troco, troco => s_val_troco_out );
    
    s_erro_estoque <= '1' when (sw_sel_cafe = '1' and s_cafe_ok = '0') else 
                      '1' when (sw_sel_cha = '1' and s_cha_ok = '0') else 
                      '1' when (s_agua_ok = '0') else '0';

    -- DEBUG LEDS
    ledr(16) <= btn_ligar; ledr(15) <= s_ficha_detectada; ledr(13) <= s_cont_start; 
    
    -- *** AQUI ESTÁ A LIGAÇÃO DO LED 14 ***
    ledr(14) <= s_sistema_ativo; 
    
    ledr(1) <= s_cafe_ok; ledr(2) <= s_cha_ok; ledr(3) <= s_agua_ok;
    ledg(6 downto 4) <= (others => '0'); ledg(8) <= '0'; ledr(17) <= '0'; ledr(12) <= '0'; ledr(11 downto 4) <= (others => '0');

    -- DISPLAYS
    hex7 <= "1000000"; 
    with s_fichas_registradas select
        hex6 <= "1000000" when "00", "1111001" when "01", "0100100" when "10", "0110000" when "11", "1111111" when others; 
    hex5 <= "1000000";
    s_troco_bits <= std_logic_vector(s_val_troco_out);
    with s_troco_bits select
        hex4 <= "1000000" when "000", "1111001" when "001", "0100100" when "010", "0110000" when "011", "0011001" when "100", "1111111" when others;

    process(w_seletor_lcd_3, s_devolver_tudo)
    begin
        if s_devolver_tudo = '1' then s_status_hex <= "0111111";
        else
            case w_seletor_lcd_3 is
                when "001" => s_status_hex <= "1000000";
                when "010" => s_status_hex <= "1111001";
                when "011" => s_status_hex <= "0111111";
                when others => s_status_hex <= "1111111";
            end case;
        end if;
    end process;
    hex3 <= s_status_hex; hex2 <= s_status_hex; hex1 <= s_status_hex; hex0 <= s_status_hex;

end Structural;