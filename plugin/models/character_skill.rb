module AresMUSH
  # A character's rating in one configured Skill (FINAL REQ-010). Skills
  # themselves are a configured catalogue (game/config/soul.yml's
  # framework.skills, read via SoulFrameworkApi) - not a separate DB model -
  # matching the verified real convention from FS3Skills (see CharacterAspect
  # for the same note in more detail).
  class CharacterSkill < Ohm::Model
    include ObjectModel

    reference :character, "AresMUSH::Character"
    # Stable key into framework.skills (e.g. "blade") - never the display name.
    attribute :skill_key
    attribute :rating, :type => DataType::Integer, :default => 0
    attribute :last_advanced_at, :type => DataType::Time

    index :skill_key
  end
end
