contract LevelStub {
  function num_objects() returns(uint) {}
  function num_monsters() returns(uint) {}

  function object_locations(uint id) returns(uint16) {}
  function object_types(uint id) returns(uint16) {}
  function monsters(uint id) returns(uint16) {}
  function monster_hp(uint id) returns(uint16) {}
  function monster_attack(uint id) returns(uint16) {}

  function pay_royalties() {}
}

contract Game {
  LevelStub[] public levels;
  uint16 public level_number;
  uint16[160] public squares;
  uint16[1000] public monster_hp;
  uint16[1000] public monster_attack;
  uint16[1000] public monster_square;
  uint num_monsters;
  uint16 public adventurer_attack;
  uint16 public adventurer_hp;
  uint16 public adventurer_level;
  uint16 adventurer_square;
  bool public over;
  bool public won;
  address public player;
  address admin;
  uint16 public equipped_item;

  modifier auth(address user) { if (msg.sender == user) _ }

  function Game() {  
    admin = msg.sender;
  }

  function initialize(uint16 character, address _player, LevelStub[] _levels) {
    player = _player;

    levels = _levels;

    if (character == 0) {
      adventurer_attack = 15;
      adventurer_hp = 150;
    } else if (character == 1) {
      adventurer_attack = 45;
      adventurer_hp = 50;
    } else {
      adventurer_attack = 30;
      adventurer_hp = 100;
    }

    adventurer_level = 1;

    load_level(0);
  }


  function get_all_squares() returns(uint16[160]) {
    return squares;
  }

  function move(uint16 direction) auth(player) {
    if (direction == 0 && ((adventurer_square % 16) != 0)) {
      uint16 target = adventurer_square - 1;
      move_to(target);
    }

    if (direction == 1 && ((adventurer_square % 16) != 15)) {
      target = adventurer_square + 1;
      move_to(target);
    }

    if (direction == 2 && adventurer_square > 15) {
      target = adventurer_square - 16;
      move_to(target);
    }

    if (direction == 3 && adventurer_square < 144) {
      target = adventurer_square + 16;
      move_to(target);
    }

    move_monsters();
  }

  function move_to(uint16 target) private {
    uint16 target_object = squares[target];
    // empty
    if (target_object == 0) {
      allow_move(target);
    }

    // staircase
    if (target_object == 2) {
      if (level_number + 1 == levels.length) {
        over = true;
        won = true;
      } else {
        load_level(level_number + 1);
      }
    }

    // potion
    if (target_object == 4) {
      adventurer_hp += 30;
      allow_move(target);
    }

    // shield or sword
    if (target_object == 5 || target_object == 6) {
      equipped_item = target_object;
      allow_move(target);
    }

    // monster
    if (target_object > 99) {
      uint16 damage = random_damage(adventurer_attack);

      if (equipped_item == 6) {
        damage += (damage * 25 / 100);
      }

      if (monster_hp[target_object] <= damage) {
        monster_hp[target_object] = 0;
        squares[target] = 0;
        level_up();
      } else {
        monster_hp[target_object] -= damage;
      }
    }
  }

  function allow_move(uint16 target) {
    squares[adventurer_square] = 0;
    squares[target] = 3;
    adventurer_square = target;
  }

  function move_monsters() private {
    for (uint16 i = 0; i < num_monsters; i++) {
      if (monster_hp[100 + i] != 0) {

        uint16 square = monster_square[100 + i];

        uint16 lr_loc;
        uint16 ud_loc;

        if (square % 16 > adventurer_square % 16) { //adventurer is to the left
          lr_loc = square - 1;
        } else {
          lr_loc = square + 1;
        }

        if (square > adventurer_square && square > 16) { //adventurer is above
          ud_loc = square - 16;
        } else {
          ud_loc = square + 16;
        }

        if (square % 16 == adventurer_square % 16) { //same column
          move_monster(100 + i, ud_loc);
        } else if (square / 16 == adventurer_square / 16) { //same row
          move_monster(100 + i, lr_loc);
        } else if ((uint(block.blockhash(block.number - 1)) % 2) == 0) {
          move_monster(100 + i, lr_loc);
        } else {
          move_monster(100 + i, ud_loc);
        }
      }
    }
  }

  function move_monster(uint16 id, uint16 target) private {
    if (squares[target] == 0) {
      squares[monster_square[id]] = 0;
      squares[target] = id;
      monster_square[id] = target;
    }

    if (squares[target] == 3) {
      uint16 damage = random_damage(monster_attack[id]);
      if (equipped_item == 5) {
        damage -= (damage * 25 / 100); //protected by shield
      }

      if (adventurer_hp <= damage) {
        adventurer_hp = 0;
        over = true;
      } else {
        adventurer_hp -= damage;
      }
    }
  }

  function random_damage(uint attack) private returns(uint16) {
    uint base = attack * 8 / 10;
    uint bonus_percent = uint(block.blockhash(block.number - 1)) % 42;

    return uint16(base + (attack * bonus_percent / 100));
  }

  function level_up() private {
    adventurer_level++;
    adventurer_attack += (adventurer_attack / 10);
    adventurer_hp += (adventurer_hp / 10);
  }

  function load_level(uint16 id) private {
    clear_level();

    level_number = id;
    LevelStub current_level = levels[id];

    uint num_objects = current_level.num_objects();
    for (uint16 i = 0; i < num_objects; i++) {
      squares[current_level.object_locations(i)] = current_level.object_types(i);
    }

    num_monsters = current_level.num_monsters();
    for (i = 0; i < num_monsters; i++) {
      id = 100 + i;
      uint16 square = current_level.monsters(i);
      squares[square] = id;
      monster_square[id] = square;
      monster_hp[id] = current_level.monster_hp(i);
      monster_attack[id] = current_level.monster_attack(i);
    }

    adventurer_square = 0;
    squares[0] = 3; // magic value for adventurer
  }

  function clear_level() private {
    delete squares;
    delete monster_hp;
    delete monster_attack;
    delete monster_square;
    delete num_monsters;
  }
}
