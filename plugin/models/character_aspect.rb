module AresMUSH
  # A character's rating in one configured Aspect (FINAL REQ-009). Aspects
  # themselves are a configured catalogue (game/config/soul.yml's
  # framework.aspects, read via SoulFrameworkApi) - not a separate DB model -
  # matching the verified real convention from FS3Skills, where ability
  # definitions (attributes, action skills, etc.) are config, and only the
  # per-character rating gets its own Ohm::Model (e.g. FS3ActionSkill).
  class CharacterAspect < Ohm::Model
    include ObjectModel

    reference :character, "AresMUSH::Character"
    # Stable key into framework.aspects (e.g. "body") - never the display name.
    attribute :aspect_key
    attribute :rating, :type => DataType::Integer, :default => 0

    index :aspect_key
  end
end
