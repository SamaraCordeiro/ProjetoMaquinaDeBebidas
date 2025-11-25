library ieee;
use ieee.std_logic_1164.all;

-- Decodder para receber o código da bebida inserida
-- É um decodder 1 para 2, feito com one-hot coding para representar as bebidas

entity dec_bebidas is
    port (
        sel : in  std_logic_vector(1 downto 0);
        res  : out std_logic_vector(1 downto 0)
    );
end entity;

-- Apenas responde nos código '01' e '10', para representar a escolha de bebidas

architecture decodder of dec_bebidas is
 begin
      res <= "01" when sel = "01" else
             "10" when sel = "10" else
             "00";
end decodder;
