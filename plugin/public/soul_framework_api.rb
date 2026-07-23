module AresMUSH
  # Read-only access to the configured Character Framework: Aspects and
  # Skills (FINAL REQ-008, REQ-009, REQ-010). Aspects and Skills are a
  # configured catalogue - game/config/soul.yml's framework.aspects and
  # framework.skills - not separate DB-backed models. This matches the
  # verified real convention from FS3Skills (plugins/fs3skills/helpers/
  # utils.rb): ability definitions live entirely in config
  # (Global.read_config("fs3skills", "action_skills"), etc.); only the
  # per-character rating gets its own Ohm::Model (see CharacterAspect,
  # CharacterSkill).
  #
  # Every method reads Global.read_config fresh (never memoized), so a
  # staff config reload picks up added/edited/removed Aspects and Skills
  # immediately.
  class SoulFrameworkApi
    def self.get_aspects
      config = Global.read_config("soul", "framework", "aspects") || {}
      config.map { |key, data| aspect_hash(key, data) }.sort_by { |a| a[:order].to_i }
    end

    def self.get_aspect(key)
      return nil if key.to_s.blank?
      config = Global.read_config("soul", "framework", "aspects") || {}
      data = config[key.to_s]
      data ? aspect_hash(key, data) : nil
    end

    def self.valid_aspect_key?(key)
      !get_aspect(key).nil?
    end

    # aspect_key: nil returns every configured Skill; pass an Aspect key to
    # scope to that Aspect only.
    def self.get_skills(aspect_key: nil)
      config = Global.read_config("soul", "framework", "skills") || {}
      skills = config.map { |key, data| skill_hash(key, data) }
      skills = skills.select { |s| s[:aspect_key] == aspect_key.to_s } if aspect_key
      skills.sort_by { |s| s[:order].to_i }
    end

    def self.get_skill(key)
      return nil if key.to_s.blank?
      config = Global.read_config("soul", "framework", "skills") || {}
      data = config[key.to_s]
      data ? skill_hash(key, data) : nil
    end

    def self.valid_skill_key?(key)
      !get_skill(key).nil?
    end

    def self.skill_min_rating
      Global.read_config("soul", "framework", "skill_min_rating") || 0
    end

    def self.skill_max_rating
      Global.read_config("soul", "framework", "skill_max_rating") || 10
    end

    # Grimoire branch -> Skill mapping (FINAL REQ-040: "map configured
    # Grimoire branches to Spirit Skills" - no dedicated Arcana Skill is
    # created). Returns the mapped skill's full hash (via get_skill, so an
    # unknown/removed skill key correctly returns nil) or nil if the branch
    # has no configured mapping. Read-only; Grimoire itself decides what to
    # do with the returned Skill - SOUL never receives or stores spell data
    # (REQ-040).
    def self.get_skill_for_grimoire_branch(branch_key)
      map = Global.read_config("soul", "integrations", "grimoire", "branch_skill_map") || {}
      skill_key = map[branch_key.to_s]
      return nil unless skill_key
      get_skill(skill_key)
    end

    private

    def self.aspect_hash(key, data)
      {
        key: key.to_s,
        name: data["name"] || key.to_s,
        description: data["description"],
        order: data["order"] || 0
      }
    end

    def self.skill_hash(key, data)
      {
        key: key.to_s,
        name: data["name"] || key.to_s,
        aspect_key: data["aspect"],
        order: data["order"] || 0
      }
    end
  end
end
