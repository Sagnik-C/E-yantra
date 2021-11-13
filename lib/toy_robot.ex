defmodule ToyRobot do
  # max x-coordinate of table top
  @table_top_x 5
  # max y-coordinate of table top
  @table_top_y :e
  # mapping of y-coordinates
  @robot_map_y_atom_to_num %{:a => 1, :b => 2, :c => 3, :d => 4, :e => 5}

  @doc """
  Places the robot to the default position of (1, A, North)

  Examples:

      iex> ToyRobot.place
      {:ok, %ToyRobot.Position{facing: :north, x: 1, y: :a}}
  """
  def place do
    {:ok, %ToyRobot.Position{}}
  end

  def place(x, y, _facing) when x < 1 or y < :a or x > @table_top_x or y > @table_top_y do
    {:failure, "Invalid position"}
  end

  def place(_x, _y, facing)
  when facing not in [:north, :east, :south, :west]
  do
    {:failure, "Invalid facing direction"}
  end

  @doc """
  Places the robot to the provided position of (x, y, facing),
  but prevents it to be placed outside of the table and facing invalid direction.

  Examples:

      iex> ToyRobot.place(1, :b, :south)
      {:ok, %ToyRobot.Position{facing: :south, x: 1, y: :b}}

      iex> ToyRobot.place(-1, :f, :north)
      {:failure, "Invalid position"}

      iex> ToyRobot.place(3, :c, :north_east)
      {:failure, "Invalid facing direction"}
  """
  def place(x, y, facing) do
    {:ok, %ToyRobot.Position{x: x, y: y, facing: facing}}
  end

  @doc """
  Provide START position to the robot as given location of (x, y, facing) and place it.
  """
  def start(x, y, facing) do
    place x, y, facing

  end

  def stop(_robot, goal_x, goal_y, _cli_proc_name) when goal_x < 1 or goal_y < :a or goal_x > @table_top_x or goal_y > @table_top_y do
    {:failure, "Invalid STOP position"}
  end

  @doc """
  Provide STOP position to the robot as given location of (x, y) and plan the path from START to STOP.
  Passing the CLI Server process name that will be used to send robot's current status after each action is taken.
  """
  def stop(robot, goal_x, goal_y, cli_proc_name) do
    if goal_x != robot.x and goal_y != robot.y do
      send_robot_status(robot, cli_proc_name)
    end
    #first determine the rotation needed for moving in the verical direction
    %ToyRobot.Position{x: x, y: y, facing: facing} = robot
    y= @robot_map_y_atom_to_num[y]
    goal_y_num = @robot_map_y_atom_to_num[goal_y]
    y_diff = goal_y_num - y
    x_diff = goal_x - x
    robot =
      cond do
        facing == :east ->
          if y_diff>=0 do
            if y_diff != 0 do
              left(robot)
            else
              robot
            end
          else
            right(robot)
          end
        facing == :west ->
          if y_diff>=0 do
            if y_diff != 0 do
              right(robot)
            else
              robot
            end
          else
            left(robot)
          end
        facing == :north ->
          if y_diff>=0 do
            robot
          else
            right(robot)

          end
        facing == :south ->
          if y_diff<=0 do
            robot
          else
            right(robot)
          end
      end
    if facing != robot.facing do
      send_robot_status(robot, cli_proc_name)
    end

    robot =
      if (facing == :south and y_diff>0) or (facing == :north and y_diff < 0) do
        right(robot)
      else
        robot
      end
    if (facing == :south and y_diff>0) or (facing == :north and y_diff<0) do
      send_robot_status(robot, cli_proc_name)
    end
    robot = moving(robot, abs(y_diff), cli_proc_name)
    robot =
      cond do
        robot.facing == :north ->
          if x_diff>=0 do
            if x_diff>0 do
              right(robot)
            else
              robot
            end
          else
            left(robot)
          end
        robot.facing == :south ->
          if x_diff>=0 do
            if x_diff>0 do
              left(robot)
            else
              robot
            end
          else
            right(robot)
          end
      end
    if robot.x != goal_x or robot.y != goal_y do
      send_robot_status(robot, cli_proc_name)
    end
    robot = moving(robot, abs(x_diff), cli_proc_name)
    if robot.x != goal_x or robot.y != goal_y do
      send_robot_status(robot, cli_proc_name)
    end
    {:ok, robot}
  end
  def moving(robot, y_diff, cli_proc_name) when y_diff==0 do
    robot
  end
  def moving(robot, y_diff, cli_proc_name) do
    robot = move(robot)
    send_robot_status(robot, cli_proc_name)
    moving(robot, y_diff-1, cli_proc_name)
  end
  # @spec moving(any, atom | %{:y => any, optional(any) => any}) :: nil

  @doc """
  Send Toy Robot's current status i.e. location (x, y) and facing
  to the CLI Server process after each action is taken.
  """
  def send_robot_status(%ToyRobot.Position{x: x, y: y, facing: facing} = _robot, cli_proc_name) do
    send(cli_proc_name, {:toyrobot_status, x, y, facing})
    # IO.puts("Sent by Toy Robot Client: #{x}, #{y}, #{facing}")
  end

  @doc """
  Provides the report of the robot's current position

  Examples:

      iex> {:ok, robot} = ToyRobot.place(2, :b, :west)
      iex> ToyRobot.report(robot)
      {2, :b, :west}
  """
  def report(%ToyRobot.Position{x: x, y: y, facing: facing} = _robot) do
    {x, y, facing}
  end

  @directions_to_the_right %{north: :east, east: :south, south: :west, west: :north}
  @doc """
  Rotates the robot to the right.
  """
  def right(%ToyRobot.Position{facing: facing} = robot) do
    %ToyRobot.Position{robot | facing: @directions_to_the_right[facing]}
  end

  @directions_to_the_left Enum.map(@directions_to_the_right, fn {from, to} -> {to, from} end)
  @doc """
  Rotates the robot to the left.
  """
  def left(%ToyRobot.Position{facing: facing} = robot) do
    %ToyRobot.Position{robot | facing: @directions_to_the_left[facing]}
  end

  @doc """
  Moves the robot to the north, but prevents it to fall.
  """
  def move(%ToyRobot.Position{x: _, y: y, facing: :north} = robot) when y < @table_top_y do
    %ToyRobot.Position{robot | y: Enum.find(@robot_map_y_atom_to_num, fn {_, val} -> val == Map.get(@robot_map_y_atom_to_num, y) + 1 end) |> elem(0)}
  end

  @doc """
  Moves the robot to the east, but prevents it to fall.
  """
  def move(%ToyRobot.Position{x: x, y: _, facing: :east} = robot) when x < @table_top_x do
    %ToyRobot.Position{robot | x: x + 1}
  end

  @doc """
  Moves the robot to the south, but prevents it to fall.
  """
  def move(%ToyRobot.Position{x: _, y: y, facing: :south} = robot) when y > :a do
    %ToyRobot.Position{robot | y: Enum.find(@robot_map_y_atom_to_num, fn {_, val} -> val == Map.get(@robot_map_y_atom_to_num, y) - 1 end) |> elem(0)}
  end

  @doc """
  Moves the robot to the west, but prevents it to fall.
  """
  def move(%ToyRobot.Position{x: x, y: _, facing: :west} = robot) when x > 1 do
    %ToyRobot.Position{robot | x: x - 1}
  end

  @doc """
  Does not change the position of the robot.
  This function used as fallback if the robot cannot move outside the table.
  """
  def move(robot), do: robot

  def failure do
    raise "Connection has been lost"
  end
end
